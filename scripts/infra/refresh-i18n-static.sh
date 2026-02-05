#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms}"
LMS_DEPLOY="${LMS_DEPLOY:-lms}"
CMS_DEPLOY="${CMS_DEPLOY:-cms}"

printf "Rebuilding LMS i18n bundles in %s...\n" "$NAMESPACE"
kubectl exec -n "$NAMESPACE" "deploy/${LMS_DEPLOY}" -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py lms compilejsi18n --output /openedx/staticfiles/js/i18n"

printf "Rebuilding CMS i18n bundles in %s...\n" "$NAMESPACE"
kubectl exec -n "$NAMESPACE" "deploy/${CMS_DEPLOY}" -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py cms compilejsi18n --output /openedx/staticfiles/studio/js/i18n"

echo "✓ i18n bundles refreshed"
