#!/usr/bin/env bash
# T142: Set GitHub repository variables for CI conditionals.
#
# These variables are referenced by CI workflows using `vars.HAS_INFISICAL`
# and `vars.HAS_GCP_SA_KEY` to conditionally skip jobs that need secrets.
#
# Usage:
#   ./scripts/infra/setup-github-repo-vars.sh
#
# Prerequisites:
#   - gh CLI authenticated with repo admin access
#   - GITHUB_REPO set (defaults to Biji-Biji-Initiative/mereka-lms)

set -euo pipefail

REPO="${GITHUB_REPO:-Biji-Biji-Initiative/mereka-lms}"

echo "=== Setting GitHub Repository Variables ==="
echo "  Repo: $REPO"
echo

# Check gh auth
if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run 'gh auth login' first."
  exit 1
fi

# Set variables
gh variable set HAS_INFISICAL --repo "$REPO" --body "true"
echo "  ✓ HAS_INFISICAL=true"

gh variable set HAS_GCP_SA_KEY --repo "$REPO" --body "true"
echo "  ✓ HAS_GCP_SA_KEY=true"

echo
echo "Done. CI workflows can now use:"
echo "  if: vars.HAS_INFISICAL == 'true'"
echo "  if: vars.HAS_GCP_SA_KEY == 'true'"
