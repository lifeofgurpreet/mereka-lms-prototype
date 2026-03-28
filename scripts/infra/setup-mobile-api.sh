#!/usr/bin/env bash
# Enable Mobile API and create OAuth application for iOS/Android apps
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OAUTH_CLIENT_ID="${OAUTH_CLIENT_ID:-mereka-mobile-app}"
OAUTH_REDIRECT_URI="${OAUTH_REDIRECT_URI:-org.openedx.app://oauth2Callback}"
APP_NAME="${APP_NAME:-Mereka Mobile App}"
ADMIN_USER="${ADMIN_USER:-admin}"

echo "=== OpenEdX Mobile API Setup ==="
echo "OAuth Client ID: ${OAUTH_CLIENT_ID}"
echo "Redirect URI: ${OAUTH_REDIRECT_URI}"
echo ""

# Detect environment (local vs k8s)
if kubectl get namespace mereka-lms &>/dev/null; then
  ENV_TYPE="kubernetes"
  echo "Detected: Kubernetes environment"
else
  ENV_TYPE="local"
  echo "Detected: Local Docker environment"
fi

# Step 1: Enable mobile features in config
echo ""
echo "=== Step 1: Checking mobile configuration ==="

if [ "$ENV_TYPE" = "local" ]; then
  cd "$REPO_ROOT"
  export TUTOR_ROOT="$(pwd)/tutor_env"
  
  if [ ! -f ".venv/bin/activate" ]; then
    echo "ERROR: Virtual environment not found. Run 'make bootstrap' first."
    exit 1
  fi
  
  source .venv/bin/activate
  
  # Check current config
  if grep -q "ENABLE_MOBILE_REST_API: true" tutor_env/config.yml 2>/dev/null; then
    echo "✓ Mobile REST API already enabled"
  else
    echo "Enabling mobile REST API..."
    tutor config save --set ENABLE_MOBILE_REST_API=true
    NEEDS_RESTART=true
  fi
  
  if grep -q "ENABLE_OAUTH2_PROVIDER: true" tutor_env/config.yml 2>/dev/null; then
    echo "✓ OAuth2 provider already enabled"
  else
    echo "Enabling OAuth2 provider..."
    tutor config save --set ENABLE_OAUTH2_PROVIDER=true
    NEEDS_RESTART=true
  fi
  
  if [ "${NEEDS_RESTART:-false}" = "true" ]; then
    echo "Preparing Tutor build context..."
    ./scripts/infra/prepare-tutor-build-context.sh --target all
    echo "Restarting services..."
    tutor local restart
  fi
fi

# Step 2: Create OAuth application
echo ""
echo "=== Step 2: Creating OAuth Application ==="

CREATE_APP_CMD="./manage.py lms create_dot_application \
  --grant-type authorization-code \
  --redirect-uris \"${OAUTH_REDIRECT_URI}\" \
  --client-id \"${OAUTH_CLIENT_ID}\" \
  --scopes \"openid profile email\" \
  --skip-authorization \
  --public \
  \"${APP_NAME}\" \
  ${ADMIN_USER}"

if [ "$ENV_TYPE" = "kubernetes" ]; then
  echo "Creating OAuth app via Kubernetes..."
  
  # Find the LMS pod
  LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  
  if [ -z "$LMS_POD" ]; then
    echo "ERROR: No LMS pod found. Trying deployment..."
    kubectl exec -n mereka-lms deployment/lms -- bash -c "$CREATE_APP_CMD" || {
      echo ""
      echo "Failed to create OAuth app. You may need to run this manually:"
      echo ""
      echo "kubectl exec -it -n mereka-lms deployment/lms -- \\"
      echo "  ./manage.py lms create_dot_application \\"
      echo "    --grant-type authorization-code \\"
      echo "    --redirect-uris \"${OAUTH_REDIRECT_URI}\" \\"
      echo "    --client-id \"${OAUTH_CLIENT_ID}\" \\"
      echo "    --scopes \"openid profile email\" \\"
      echo "    --skip-authorization \\"
      echo "    --public \\"
      echo "    \"${APP_NAME}\" \\"
      echo "    ${ADMIN_USER}"
      exit 1
    }
  else
    echo "Found LMS pod: $LMS_POD"
    kubectl exec -n mereka-lms "$LMS_POD" -- bash -c "$CREATE_APP_CMD"
  fi
else
  echo "Creating OAuth app via local Docker..."
  tutor local run lms bash -c "$CREATE_APP_CMD"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "OAuth Client ID: ${OAUTH_CLIENT_ID}"
echo "Use this in your iOS app config.yaml:"
echo ""
echo "  OAUTH_CLIENT_ID: \"${OAUTH_CLIENT_ID}\""
echo ""
echo "Next steps:"
echo "1. Clone the iOS app: git clone https://github.com/openedx/openedx-app-ios.git"
echo "2. Configure using: docs/MOBILE_IOS_APP_SETUP.md"
echo "3. Build in Xcode and deploy via TestFlight"
