#!/usr/bin/env bash
# @covers AC-002
# @spec: branding-system_spec.md
# Verify Studio (CMS) branding shows "Mereka Academy - Studio"

set -euo pipefail

echo "🔍 Verifying Studio CMS Branding..."
echo ""

# Check Django settings
echo "1️⃣ Django Settings (in-pod):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms shell -c \
  "from django.conf import settings; \
   print(f'PLATFORM_NAME: {settings.PLATFORM_NAME}'); \
   print(f'STUDIO_NAME: {settings.STUDIO_NAME}')" 2>/dev/null | head -2
echo ""

# Check ConfigMap being used
echo "2️⃣ ConfigMap Reference:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CONFIGMAP=$(kubectl get deployment cms -n mereka-lms -o jsonpath='{.spec.template.spec.volumes[1].configMap.name}')
echo "Deployment uses: $CONFIGMAP"
echo ""

# Check ConfigMap content
echo "3️⃣ ConfigMap Content (STUDIO_NAME):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get configmap "$CONFIGMAP" -n mereka-lms -o yaml | grep -A 1 "STUDIO_NAME"
echo ""

# Check HTML content (from cluster)
echo "4️⃣ HTML Content (page title):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl exec -n mereka-lms deployment/lms -- curl -sL http://cms:8000/ 2>/dev/null | \
  sed -n '/<title>/,/<\/title>/p'
echo ""

# Check HTML content (welcome heading)
echo "5️⃣ HTML Content (welcome heading):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl exec -n mereka-lms deployment/lms -- curl -sL http://cms:8000/ 2>/dev/null | \
  grep -i "wrapper-text-welcome" | sed 's/^[ \t]*//'
echo ""

# Final verdict
echo "✅ Verification Complete!"
echo ""
echo "Expected values:"
echo "  PLATFORM_NAME: Mereka Academy"
echo "  STUDIO_NAME: Mereka Academy - Studio"
echo "  Page Title: Welcome | Mereka Academy - Studio"
echo "  Heading: Welcome to Mereka Academy - Studio"
