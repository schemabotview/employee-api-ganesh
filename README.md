# employee-api-ganesh

PoC: a FastAPI service over PostgreSQL, deployed to AWS ECS Fargate, with
Terraform gated on pull requests and applied on merge.

## Who does what

| Piece | Owner |
|---|---|
| Infrastructure (ECR, ECS, SG, logs) | **Terraform**, run by **GitHub Actions** |
| `terraform plan` on every PR | GitHub Actions, posted as a PR comment |
| `terraform apply` on merge to `main` | GitHub Actions |
| App build, smoke test, push to ECR, ECS rollout | **Jenkins** (in Docker) |

Infrastructure and application are deliberately split so Actions and Jenkins
never contend for the same Terraform state.

## Layout

```
main.py                        FastAPI app (/health, /employees)
Dockerfile                     app image
docker-compose.yml             local API + Postgres
init.sql                       employees table + seed rows
terraform/                     ECR, ECS Fargate, SG in the default VPC
bootstrap/bootstrap.sh         one-off: state bucket + GitHub OIDC role
.github/workflows/terraform.yml  plan on PR, apply on main
Jenkinsfile                    app pipeline
jenkins/                       Jenkins image + compose
```

## Run it locally

```bash
docker compose up --build
curl localhost:8000/health
curl localhost:8000/employees
curl -X POST localhost:8000/employees \
  -H 'content-type: application/json' \
  -d '{"name":"Katherine Johnson","dept":"Research","salary":99000}'
```

## One-off setup

```bash
export AWS_PROFILE=AdministratorAccess-743737183475
./bootstrap/bootstrap.sh
```

That creates the S3 state bucket, the GitHub Actions OIDC provider, and the
role Actions assumes. Then wire up the repo side:

```bash
DB_PASSWORD='<password>' ./bootstrap/github-setup.sh
```

That sets the repo variables and secret the workflow reads, and protects `main`
so changes have to arrive via a PR — without that, the plan gate is decorative.

## The flow

1. Branch, change something under `terraform/`, open a PR.
2. Actions runs `fmt -check`, `validate`, `plan`, and comments the plan on the PR.
3. Merge. Actions runs `apply -auto-approve` against the same state.
4. Jenkins (polling every 2 min) builds the image, smoke-tests it, pushes to
   ECR, and forces a new ECS deployment.

## Terraform variables

`region`, `app_name`, `desired_count`, `image_tag`, `db_name`, `db_user` have
defaults. These need values:

| Variable | Supplied by |
|---|---|
| `allowed_cidr` | repo variable `TF_VAR_ALLOWED_CIDR` |
| `db_host` | repo variable `TF_VAR_DB_HOST` |
| `db_password` | repo secret `TF_VAR_DB_PASSWORD` |

For local runs, copy `terraform/example.tfvars` to `terraform/terraform.tfvars`
(gitignored) and `terraform plan -var-file=terraform.tfvars`.

## Notes and shortcuts

- **Postgres is not in Terraform.** The deployed task reads `DB_HOST` from a
  variable and points at a database you provide. `docker-compose.yml` runs one
  locally for development. Add an `aws_db_instance` if you want RDS in the apply.
- No ALB — the Fargate task gets a public IP, reachable on `:8000` from
  `allowed_cidr` only.
- No DynamoDB state lock. Fine for one person, not for a team.
- The CI role has `PowerUserAccess` + `IAMFullAccess` so plan/apply never
  stalls on permissions. Tighten before this is anything but a PoC.

## Tear down

```bash
cd terraform
terraform destroy -var-file=terraform.tfvars
```
