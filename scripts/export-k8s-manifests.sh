#!/bin/bash
set -euo pipefail

# DEPRECATED: legacy Tutor -> deploy/k8s export path.
# Canonical release flow:
#   scripts/infra/release-openedx-gitops.sh
# Temporary bypass (emergency only):
#   ALLOW_LEGACY_TUTOR_K8S=1 ./scripts/export-k8s-manifests.sh
if [[ "${ALLOW_LEGACY_TUTOR_K8S:-0}" != "1" ]]; then
  echo "DEPRECATED: scripts/export-k8s-manifests.sh is disabled by default." >&2
  echo "Use scripts/infra/release-openedx-gitops.sh for canonical GitOps flow." >&2
  echo "Set ALLOW_LEGACY_TUTOR_K8S=1 only for emergency legacy recovery." >&2
  exit 1
fi

echo "WARNING: running deprecated legacy path (ALLOW_LEGACY_TUTOR_K8S=1)." >&2

# Export K8s manifests from Tutor environment to GitOps deploy directory
# This script re-exports manifests when Tutor configuration changes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TUTOR_ENV="$PROJECT_ROOT/tutor_env/env"
DEPLOY_BASE="$PROJECT_ROOT/deploy/k8s/base"

echo "==> Exporting K8s manifests from Tutor to GitOps base..."

# Check if source directories exist
if [[ ! -d "$TUTOR_ENV" ]]; then
    echo "ERROR: Tutor environment not found at $TUTOR_ENV"
    echo "Run 'tutor config save' first to generate manifests"
    exit 1
fi

# Create deploy/k8s/base directory if it doesn't exist
mkdir -p "$DEPLOY_BASE"

echo "  - Copying K8s manifests..."
cp "$TUTOR_ENV/k8s/deployments.yml" "$DEPLOY_BASE/"
cp "$TUTOR_ENV/k8s/services.yml" "$DEPLOY_BASE/"
cp "$TUTOR_ENV/k8s/volumes.yml" "$DEPLOY_BASE/"
cp "$TUTOR_ENV/k8s/namespace.yml" "$DEPLOY_BASE/"

echo "  - Updating namespace to mereka-lms..."
sed -i 's/name: openedx/name: mereka-lms/g' "$DEPLOY_BASE/namespace.yml"

echo "  - Copying apps/ directory..."
rm -rf "$DEPLOY_BASE/apps"
cp -r "$TUTOR_ENV/apps" "$DEPLOY_BASE/"

echo "  - Copying plugins/ directory..."
rm -rf "$DEPLOY_BASE/plugins"
cp -r "$TUTOR_ENV/plugins" "$DEPLOY_BASE/"

echo "  - Creating kustomization.yaml..."
cat > "$DEPLOY_BASE/kustomization.yaml" <<'EOF'
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yml
- deployments.yml
- services.yml
- volumes.yml

# namespace to deploy all Resources to
namespace: mereka-lms

# annotations added to all Resources
# https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/commonannotations/
commonAnnotations:
  app.kubernetes.io/version: 18.2.2

# labels (and label selectors) added to all Resources
# https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
# https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/commonlabels/
commonLabels:
  app.kubernetes.io/instance: mereka-lms
  app.kubernetes.io/part-of: mereka-lms
  app.kubernetes.io/managed-by: tutor


configMapGenerator:
- name: caddy-config
  files:
  - apps/caddy/Caddyfile
  options:
    labels:
        app.kubernetes.io/name: caddy
- name: openedx-settings-lms
  files:
  - apps/openedx/settings/lms/__init__.py
  - apps/openedx/settings/lms/development.py
  - apps/openedx/settings/lms/production.py
  - apps/openedx/settings/lms/test.py
  options:
    labels:
        app.kubernetes.io/name: openedx
- name: openedx-settings-cms
  files:
  - apps/openedx/settings/cms/__init__.py
  - apps/openedx/settings/cms/development.py
  - apps/openedx/settings/cms/production.py
  - apps/openedx/settings/cms/test.py
  options:
    labels:
        app.kubernetes.io/name: openedx
- name: openedx-config
  files:
  - apps/openedx/config/cms.env.yml
  - apps/openedx/config/lms.env.yml
  options:
    labels:
        app.kubernetes.io/name: openedx
- name: openedx-uwsgi-config
  files:
  - apps/openedx/uwsgi.ini
  options:
    labels:
        app.kubernetes.io/name: openedx
- name: redis-config
  files:
  - apps/redis/redis.conf
  options:
    labels:
        app.kubernetes.io/name: redis
- name: discovery-settings
  files:
    - plugins/discovery/apps/settings/tutor/production.py
- name: ecommerce-settings
  files:
  - plugins/ecommerce/apps/ecommerce/settings/__init__.py
  - plugins/ecommerce/apps/ecommerce/settings/development.py
  - plugins/ecommerce/apps/ecommerce/settings/paymentprocessors.json
  - plugins/ecommerce/apps/ecommerce/settings/production.py
- name: ecommerce-worker-settings
  files:
  - plugins/ecommerce/apps/ecommerce-worker/settings/__init__.py
  - plugins/ecommerce/apps/ecommerce-worker/settings/production.py
- name: mfe-caddy-config
  files:
    - plugins/mfe/apps/mfe/Caddyfile
  options:
    labels:
        app.kubernetes.io/name: mfe
- name: notes-settings
  files:
    - plugins/notes/apps/settings/tutor.py
- name: xqueue-settings
  files:
    - plugins/xqueue/apps/settings/tutor.py
EOF

echo ""
echo "==> Export complete!"
echo ""
echo "Files created in: $DEPLOY_BASE"
echo ""
echo "Next steps:"
echo "  1. Review the exported manifests in deploy/k8s/base/"
echo "  2. Create overlays for different environments (local, production)"
echo "  3. Test with: kubectl kustomize $DEPLOY_BASE"
echo ""
