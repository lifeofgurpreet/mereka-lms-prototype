#!/usr/bin/env bash
# Helper script to configure Google OAuth for OpenEdX LMS
# Usage: ./scripts/infra/setup-google-oauth.sh [--client-id CLIENT_ID] [--client-secret SECRET]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/infrastructure/tutor/tutor-env.sh"

CLIENT_ID=""
CLIENT_SECRET=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --client-secret)
      CLIENT_SECRET="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--client-id CLIENT_ID] [--client-secret SECRET]" >&2
      exit 1
      ;;
  esac
done

# Prompt for credentials if not provided
if [[ -z "$CLIENT_ID" ]]; then
  echo "Enter your Google OAuth Client ID (from Google Cloud Console):"
  read -r CLIENT_ID
fi

if [[ -z "$CLIENT_SECRET" ]]; then
  echo "Enter your Google OAuth Client Secret (from Google Cloud Console):"
  read -rs CLIENT_SECRET
  echo ""
fi

# Validate inputs
if [[ -z "$CLIENT_ID" ]] || [[ -z "$CLIENT_SECRET" ]]; then
  echo "Error: Both Client ID and Client Secret are required" >&2
  exit 1
fi

# Configure Tutor
echo "Configuring Google OAuth in Tutor..."
"$REPO_ROOT/scripts/infra/tutor-config-save.sh" \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_KEY="$CLIENT_ID" \
  --set SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET="$CLIENT_SECRET"

echo ""
echo "✅ Google OAuth credentials configured successfully!"
echo ""
echo "Next steps:"
echo "1. Refresh the local stack:"
echo "   make tutor-restart"
echo ""
echo "   For deployed environments, commit the source change and use the"
echo "   sanctioned operator / GitOps path documented in:"
echo "   docs/guides/admin/K8S_OPERATIONS_GUIDE.md"
echo ""
echo "2. Enable the Google provider in Django admin:"
echo "   - Navigate to: http://localhost/admin/ (or https://academyv2.mereka.io/admin/)"
echo "   - Go to: Third Party Authentication > Provider Configuration (SSO)"
echo "   - Add a new provider:"
echo "     * Provider: Google"
echo "     * Name: Google OAuth2"
echo "     * Enabled: ✓"
echo "     * Site: Select your site"
echo ""
echo "3. Test Google login on your LMS login page"
echo ""
echo "For detailed instructions, see: docs/guides/integrations/GOOGLE_OAUTH_SETUP.md"

