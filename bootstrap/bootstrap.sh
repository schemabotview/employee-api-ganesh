#!/usr/bin/env bash
# One-off setup so CI can run Terraform. Safe to re-run (idempotent).
#
#   AWS_PROFILE=AdministratorAccess-743737183475 ./bootstrap/bootstrap.sh
set -euo pipefail

REGION="${AWS_REGION:-eu-west-2}"
REPO="${REPO:-schemabotview/employee-api-ganesh}"
APP="employee-api-ganesh"

# The lab account. Everything below lives here, including the shared state
# bucket, so refuse to run anywhere else rather than half-create things.
EXPECTED_ACCOUNT="743737183475"
PROFILE_HINT="AdministratorAccess-${EXPECTED_ACCOUNT}"

# Shared team bucket, declared in terraform/provider.tf. Not created here.
BUCKET="employee-api-tfstate-${EXPECTED_ACCOUNT}"
ROLE="${APP}-gha-role"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

if [ "$ACCOUNT" != "$EXPECTED_ACCOUNT" ]; then
  cat >&2 <<MSG
ERROR: wrong AWS account.

  credentials point at: ${ACCOUNT}
  this script expects:  ${EXPECTED_ACCOUNT}

AWS_PROFILE is currently "${AWS_PROFILE:-default}". Re-run as:

  AWS_PROFILE=${PROFILE_HINT} ./bootstrap/bootstrap.sh

If that profile's SSO session has expired, refresh it first:

  aws sso login --profile ${PROFILE_HINT}
MSG
  exit 1
fi

echo "account=${ACCOUNT} region=${REGION} role=${ROLE}"
echo "state=s3://${BUCKET}/terraform/${APP}/terraform.tfstate"

if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "ERROR: shared state bucket ${BUCKET} is not reachable from this account" >&2
  exit 1
fi

# --- 1. GitHub Actions OIDC provider ------------------------------------
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

# --- 2. IAM role GitHub Actions assumes ---------------------------------
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


cat <<SUMMARY

Done. Set these on the GitHub repo:

  gh variable set AWS_ROLE_ARN        --body "${ROLE_ARN}"      --repo ${REPO}
  gh variable set TF_VAR_allowed_cidr --body "<your.ip>/32"     --repo ${REPO}
  gh secret   set TF_VAR_db_password --body "<password>"        --repo ${REPO}
SUMMARY
