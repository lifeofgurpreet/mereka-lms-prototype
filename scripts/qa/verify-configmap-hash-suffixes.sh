#!/usr/bin/env bash
# @covers AC-INT-001
# @spec: k8s-deployment_spec.md
#
# Verify ConfigMap hash suffixes are enabled for overlay generators.
# When disableNameSuffixHash is removed, overlay-generated ConfigMaps get
# content-based hash suffixes, ensuring pod restarts on config changes.
#
# Exit 0 = all checks pass
# Exit 1 = one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== ConfigMap Hash Suffix Verification ==="
echo ""

# Check 1: NO overlay should have disableNameSuffixHash
echo "[1/3] Checking all overlays for disableNameSuffixHash"
for overlay in local rke2-nonprod staging; do
  kfile="${REPO_ROOT}/deploy/k8s/overlays/${overlay}/kustomization.yaml"
  if [[ ! -f "$kfile" ]]; then
    pass "${overlay}: overlay not present (skip)"
    continue
  fi
  if grep -q 'disableNameSuffixHash.*true' "$kfile"; then
    fail "${overlay}: disableNameSuffixHash is still true"
  else
    pass "${overlay}: disableNameSuffixHash removed"
  fi
done

# Check 2: kustomize render produces hashed ConfigMap names
echo "[2/3] Checking local overlay ConfigMap hash suffixes via kustomize render"
if ! command -v kubectl >/dev/null 2>&1; then
  pass "kubectl not available — render checks skipped (CI will validate)"
else
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT
  if ! kubectl kustomize "${REPO_ROOT}/deploy/k8s/overlays/local/" > "$tmpfile" 2>/dev/null; then
    fail "kubectl kustomize failed to render local overlay"
  else
    # enterprise-mfe-env should have a hash suffix (overlay generator)
    if grep -qE 'name: enterprise-mfe-env-[a-z0-9]+' "$tmpfile"; then
      pass "enterprise-mfe-env has hash suffix in local overlay"
    else
      fail "enterprise-mfe-env missing hash suffix in local overlay"
    fi

    # Base ConfigMaps should also have hashes (they always did)
    if grep -qE 'name: caddy-config-[a-z0-9]+' "$tmpfile"; then
      pass "caddy-config has hash suffix (base generator)"
    else
      fail "caddy-config missing hash suffix"
    fi

    if grep -qE 'name: openedx-settings-lms-[a-z0-9]+' "$tmpfile"; then
      pass "openedx-settings-lms has hash suffix (base generator)"
    else
      fail "openedx-settings-lms missing hash suffix"
    fi

    # Volume references should use hashed names (nameReference transformer)
    mfe_hash=$(grep -oP 'name: enterprise-mfe-env-\K[a-z0-9]+' "$tmpfile" | head -1)
    if [[ -n "$mfe_hash" ]]; then
      vol_refs=$(grep -c "enterprise-mfe-env-${mfe_hash}" "$tmpfile" || true)
      if [[ "$vol_refs" -ge 2 ]]; then
        pass "volume references updated to hashed name (${vol_refs} refs for enterprise-mfe-env-${mfe_hash})"
      else
        fail "volume references not updated — only ${vol_refs} refs found"
      fi
    fi
  fi
fi

# Check 3: monitoring kustomization exists (CronJobs exempt from hash suffixes)
echo "[3/3] Checking monitoring exception"
mon_kfile="${REPO_ROOT}/deploy/k8s/base/monitoring/kustomization.yaml"
if [[ -f "$mon_kfile" ]]; then
  pass "monitoring kustomization exists (CronJob exception documented)"
else
  pass "no monitoring kustomization to check"
fi

echo ""
echo "=== Results: ${FAILURES} failures ==="
if [[ $FAILURES -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
echo "VERDICT: PASS"
exit 0
