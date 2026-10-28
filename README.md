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
terraform/                     ECR, ECS Fargate + Postgres sidecar, SG
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
export AWS_PROFILE=AdministratorAccess-743737183475   # not the default profile
aws sso login --profile "$AWS_PROFILE"                # if the session expired
./bootstrap/bootstrap.sh
```

Everything lives in lab account `743737183475`. `bootstrap.sh` checks the
account before doing anything and stops if your credentials point elsewhere —
the `default` profile is a different account.

That creates the GitHub Actions OIDC provider and the role Actions assumes.
Then wire up the repo side:

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

Because the database is a sidecar, step 4 restarts Postgres too and the
employee rows reset to the three seeded ones.

## Terraform state

State lives in the shared team bucket, one prefix per person:

```
s3://employee-api-tfstate-743737183475/terraform/employee-api-ganesh/terraform.tfstate
```

That is declared in `terraform/provider.tf`, so `terraform init` needs no
extra flags. The bucket is versioned, and there is no DynamoDB lock table —
fine while everyone stays inside their own prefix.

## Terraform variables

`region`, `app_name`, `desired_count`, `image_tag`, `db_host`, `db_name`,
`db_user` and `postgres_image` all have defaults. These need values:

| Variable | Supplied by |
|---|---|
| `allowed_cidr` | repo variable `TF_VAR_ALLOWED_CIDR` |
| `db_password` | repo secret `TF_VAR_DB_PASSWORD` |

For local runs, copy `terraform/example.tfvars` to `terraform/terraform.tfvars`
(gitignored) and `terraform plan -var-file=terraform.tfvars`.

## Notes and shortcuts

- **Postgres runs as a sidecar, not RDS.** The ECS task has two containers:
  `postgres` and the API. They share the task's network namespace, so
  `DB_HOST=localhost` works and no RDS bill appears. The cost is that the data
  sits on the task's ephemeral disk and is **wiped on every redeploy** — fine
  for a demo, useless for anything that needs to persist. Swap in an
  `aws_db_instance` and point `db_host` at its endpoint when that matters.
- **The schema is created by the app, not by SQL on disk.** `ensure_schema()`
  in `main.py` runs at startup, creates `employees` if missing and seeds three
  rows, retrying while Postgres comes up. That is why there is no `init.sql`:
  Fargate has nowhere to mount one, so doing it in the app keeps local and
  deployed behaviour identical.
- Task size is 512 CPU / 1024 MB to fit both containers.
- No ALB — the Fargate task gets a public IP, reachable on `:8000` from
  `allowed_cidr` only.
- No DynamoDB state lock. Everyone shares the bucket but not the prefix, so
  concurrent applies can't corrupt each other's state.
- The CI role has `PowerUserAccess` + `IAMFullAccess` so plan/apply never
  stalls on permissions. Tighten before this is anything but a PoC.

## Tear down

```bash
cd terraform
terraform destroy -var-file=terraform.tfvars
```
