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
OIDC_HOST="token.actions.githubusercontent.com"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

if [ "$ACCOUNT" != "$EXPECTED_ACCOUNT" ]; then
  echo "ERROR: wrong AWS account." >&2
  echo "" >&2
  echo "  credentials point at: ${ACCOUNT}" >&2
  echo "  this script expects:  ${EXPECTED_ACCOUNT}" >&2
  echo "" >&2
  echo "AWS_PROFILE is currently \"${AWS_PROFILE:-default}\". Re-run as:" >&2
  echo "" >&2
  echo "  AWS_PROFILE=${PROFILE_HINT} ./bootstrap/bootstrap.sh" >&2
  echo "" >&2
  echo "If that profile's SSO session has expired, refresh it first:" >&2
  echo "" >&2
  echo "  aws sso login --profile ${PROFILE_HINT}" >&2
  exit 1
fi

echo "account=${ACCOUNT} region=${REGION} role=${ROLE}"
echo "state=s3://${BUCKET}/terraform/${APP}/terraform.tfstate"

if ! aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "ERROR: shared state bucket ${BUCKET} is not reachable from this account" >&2
  exit 1
fi
echo "state bucket reachable"

# --- 1. GitHub Actions OIDC provider ------------------------------------
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/${OIDC_HOST}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "OIDC provider already exists"
else
  echo "creating OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_HOST}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" >/dev/null
fi

# --- 2. IAM role GitHub Actions assumes ---------------------------------
# Built with printf rather than a heredoc so the quoting stays obvious.
TRUST="$(printf '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"%s"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"%s:aud":"sts.amazonaws.com"},"StringLike":{"%s:sub":"repo:%s:*"}}}]}' \
  "$OIDC_ARN" "$OIDC_HOST" "$OIDC_HOST" "$REPO")"

if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  echo "role ${ROLE} exists, refreshing trust policy"
  aws iam update-assume-role-policy \
    --role-name "$ROLE" \
    --policy-document "$TRUST"
else
  echo "creating role ${ROLE}"
  aws iam create-role \
    --role-name "$ROLE" \
    --description "Terraform plan/apply from GitHub Actions for ${REPO}" \
    --assume-role-policy-document "$TRUST" >/dev/null
fi

# PoC scope: broad permissions so plan/apply never stalls on IAM.
# Tighten to ECR/ECS/IAM/Logs/EC2/S3 before anything real.
for policy in PowerUserAccess IAMFullAccess; do
  aws iam attach-role-policy \
    --role-name "$ROLE" \
    --policy-arn "arn:aws:iam::aws:policy/${policy}"
  echo "attached ${policy}"
done

ROLE_ARN="$(aws iam get-role --role-name "$ROLE" --query Role.Arn --output text)"

echo ""
echo "Done. Role ARN:"
echo "  ${ROLE_ARN}"
echo ""
echo "Now wire up the repo side:"
echo "  DB_PASSWORD='<pick one>' ./bootstrap/github-setup.sh"
