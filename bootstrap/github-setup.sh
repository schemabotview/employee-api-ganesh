#!/usr/bin/env bash
# Run AFTER bootstrap.sh. Sets the repo variables/secret the workflow reads.
set -euo pipefail

REPO="${REPO:-schemabotview/employee-api-ganesh}"
ACCOUNT="${ACCOUNT:-743737183475}" # the lab account, same as bootstrap.sh
APP="employee-api-ganesh"

# Security group ingress for the API. Detected at run time so it follows you.
MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
echo "allowing ${MY_IP}/32 on port 8000"

gh variable set AWS_ROLE_ARN \
  --repo "$REPO" --body "arn:aws:iam::${ACCOUNT}:role/${APP}-gha-role"

gh variable set TF_VAR_ALLOWED_CIDR \
  --repo "$REPO" --body "${MY_IP}/32"

# Initialises the Postgres sidecar and is what the API authenticates with.
# Only needed the first time, or to rotate it - the script is otherwise
# re-runnable without re-supplying the password.
if [ -n "${DB_PASSWORD:-}" ]; then
  gh secret set TF_VAR_DB_PASSWORD --repo "$REPO" --body "$DB_PASSWORD"
elif gh secret list --repo "$REPO" 2>/dev/null | grep -q '^TF_VAR_DB_PASSWORD'; then
  echo "TF_VAR_DB_PASSWORD already set, leaving it alone"
  echo "  (to rotate: DB_PASSWORD='<new>' ./bootstrap/github-setup.sh)"
else
  echo "ERROR: TF_VAR_DB_PASSWORD is not set yet. Re-run as:" >&2
  echo "" >&2
  echo "  DB_PASSWORD='<pick one>' ./bootstrap/github-setup.sh" >&2
  echo "" >&2
  echo "Avoid a value that appears in your resource names - GitHub masks the" >&2
  echo "secret everywhere in logs, which would redact them from the plan." >&2
  exit 1
fi

# Make the PR gate meaningful: no direct pushes to main.
# This endpoint rejects dotted -f keys and requires all four top-level
# fields to be present, so send a real JSON body.
printf '%s' '{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}' | gh api -X PUT "repos/${REPO}/branches/main/protection" --input - >/dev/null \
  && echo "main is now protected: changes must arrive via a PR"

echo ""
echo "Open a PR touching terraform/ and the plan should appear as a comment."

echo
echo "variables:"
gh variable list --repo "$REPO"
