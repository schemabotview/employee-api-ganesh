#!/usr/bin/env bash
# Run AFTER bootstrap.sh. Sets the repo variables/secret the workflow reads.
set -euo pipefail

REPO="${REPO:-schemabotview/employee-api-ganesh}"
ACCOUNT="${ACCOUNT:-743737183475}"
APP="employee-api-ganesh"

# Security group ingress for the API. Detected at run time so it follows you.
MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
echo "allowing ${MY_IP}/32 on port 8000"

gh variable set AWS_ROLE_ARN \
  --repo "$REPO" --body "arn:aws:iam::${ACCOUNT}:role/${APP}-gha-role"

gh variable set TF_STATE_BUCKET \
  --repo "$REPO" --body "${APP}-tfstate-${ACCOUNT}"

gh variable set TF_VAR_ALLOWED_CIDR \
  --repo "$REPO" --body "${MY_IP}/32"

# No RDS in this PoC - the deployed task points at whatever you give it here.
gh variable set TF_VAR_DB_HOST \
  --repo "$REPO" --body "${DB_HOST:-localhost}"

gh secret set TF_VAR_DB_PASSWORD \
  --repo "$REPO" --body "${DB_PASSWORD:?set DB_PASSWORD before running}"

# Make the PR gate meaningful: no direct pushes to main.
gh api -X PUT "repos/${REPO}/branches/main/protection" \
  -f 'required_pull_request_reviews.required_approving_review_count=0' \
  -F enforce_admins=false \
  -F required_status_checks=null \
  -F restrictions=null >/dev/null && echo "main is now protected"

echo
echo "variables:"
gh variable list --repo "$REPO"
