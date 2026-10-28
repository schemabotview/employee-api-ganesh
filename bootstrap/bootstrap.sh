#!/usr/bin/env bash
# One-off setup so CI can run Terraform. Safe to re-run (idempotent).
#
#   AWS_PROFILE=AdministratorAccess-743737183475 ./bootstrap/bootstrap.sh
set -euo pipefail

REGION="${AWS_REGION:-eu-west-2}"
REPO="${REPO:-schemabotview/employee-api-ganesh}"
APP="employee-api-ganesh"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${APP}-tfstate-${ACCOUNT}"
ROLE="${APP}-gha-role"

echo "account=${ACCOUNT} region=${REGION} bucket=${BUCKET} role=${ROLE}"

# --- 1. S3 bucket for Terraform state -----------------------------------
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "bucket ${BUCKET} already exists"
else
  echo "creating bucket ${BUCKET}"
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=${REGION}"
fi

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# --- 2. GitHub Actions OIDC provider ------------------------------------
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "OIDC provider already exists"
else
  echo "creating OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
fi

# --- 3. IAM role GitHub Actions assumes ---------------------------------
TRUST="$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:${REPO}:*" }
    }
  }]
}
JSON
)"

if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  echo "role ${ROLE} exists, refreshing trust policy"
  aws iam update-assume-role-policy --role-name "$ROLE" --policy-document "$TRUST"
else
  echo "creating role ${ROLE}"
  aws iam create-role \
    --role-name "$ROLE" \
    --description "Terraform plan/apply from GitHub Actions for ${REPO}" \
    --assume-role-policy-document "$TRUST"
fi

# PoC scope: broad permissions so plan/apply never stalls on IAM.
# Tighten to ECR/ECS/IAM/Logs/EC2/S3 before anything real.
aws iam attach-role-policy \
  --role-name "$ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"

aws iam attach-role-policy \
  --role-name "$ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/IAMFullAccess"

ROLE_ARN="$(aws iam get-role --role-name "$ROLE" --query Role.Arn --output text)"

# --- 4. Backend config Terraform inits with -----------------------------
cat > "$(dirname "$0")/backend.hcl" <<HCL
bucket = "${BUCKET}"
HCL

cat <<SUMMARY

Done. Set these on the GitHub repo:

  gh variable set AWS_ROLE_ARN   --body "${ROLE_ARN}"           --repo ${REPO}
  gh variable set TF_STATE_BUCKET --body "${BUCKET}"            --repo ${REPO}
  gh variable set TF_VAR_allowed_cidr --body "<your.ip>/32"     --repo ${REPO}
  gh variable set TF_VAR_db_host --body "<postgres host>"       --repo ${REPO}
  gh secret   set TF_VAR_db_password --body "<password>"        --repo ${REPO}
SUMMARY
