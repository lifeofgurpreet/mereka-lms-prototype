#!/usr/bin/env bash
# @covers AC-001
# @spec: slo-sla-service-level-management_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

LMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
LMS_MULTI="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py"
CMS_MULTI="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/mereka_multisite.py"

echo "Verifying SITE_ID hardening contract..."

for file in "$LMS_PROD" "$CMS_PROD"; do
  if rg -n '^[[:space:]]*SITE_ID[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$' "$file" >/dev/null; then
    echo "❌ Hardcoded numeric SITE_ID found in ${file#"$REPO_ROOT"/}"
    exit 1
  fi
  if ! rg -n 'SITE_ID[[:space:]]*=[[:space:]]*int\(os\.environ\.get\("DJANGO_SITE_ID"' "$file" >/dev/null; then
    echo "❌ Missing DJANGO_SITE_ID-based SITE_ID assignment in ${file#"$REPO_ROOT"/}"
    exit 1
  fi
done

for file in "$LMS_MULTI" "$CMS_MULTI"; do
  if ! rg -n '^def _fallback_site_without_request\(Site\):' "$file" >/dev/null; then
    echo "❌ Missing _fallback_site_without_request helper in ${file#"$REPO_ROOT"/}"
    exit 1
  fi
  if ! rg -n 'site = _fallback_site_without_request\(Site\)' "$file" >/dev/null; then
    echo "❌ Missing fallback invocation in get_current for ${file#"$REPO_ROOT"/}"
    exit 1
  fi
done

echo "✓ SITE_ID hardening contract passed"
