#!/usr/bin/env bash
# @spec: multi-tenancy-architecture_spec.md
# @covers AC-MT-001: mereka_tenancy in INSTALLED_APPS
# @covers AC-MT-002: TenantResolutionMiddleware in MIDDLEWARE
# @covers AC-MT-003: mereka_tenancy pip-installable from source
# @covers AC-MT-004: Django migration 0001_initial exists
# @covers AC-MT-005: mereka_tenancy in Dockerfile build paths
set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_PY="$PLUGIN_MAIN"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_PY="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
TENANCY_SRC="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy"
# setup.py uses package_dir={'mereka_tenancy': '.'} — package root IS the multi-tenancy/ dir
MIGRATION="$TENANCY_SRC/migrations/0001_initial.py"

echo "========================================"
echo "mereka_tenancy Source Verification"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-MT-003: Plugin package installable from source
# -----------------------------------------------------------------------
echo "AC-MT-003: mereka_tenancy package source"

if [[ ! -d "$TENANCY_SRC" ]]; then
  fail "multi-tenancy plugin directory missing: infrastructure/tutor/plugins/multi-tenancy"
else
  pass "multi-tenancy plugin directory exists"

  if [[ -f "$TENANCY_SRC/setup.py" ]]; then
    pass "setup.py present (pip install -e compatible)"
  else
    fail "setup.py missing — cannot pip install -e"
  fi

  # Package root IS multi-tenancy/ (package_dir={'mereka_tenancy': '.'} in setup.py)
  if [[ -f "$TENANCY_SRC/__init__.py" ]]; then
    pass "mereka_tenancy Python package exists (__init__.py at package root)"
  else
    fail "__init__.py missing at $TENANCY_SRC — not a valid Python package"
  fi

  if [[ -f "$TENANCY_SRC/apps.py" ]]; then
    pass "apps.py present (Django AppConfig)"
  else
    fail "apps.py missing — Django app not configured"
  fi

  if [[ -f "$TENANCY_SRC/models.py" ]]; then
    pass "models.py present (TenantConfig model)"
    if grep -q "class TenantConfig" "$TENANCY_SRC/models.py"; then
      pass "TenantConfig model defined"
    else
      fail "TenantConfig model not found in models.py"
    fi
  else
    fail "models.py missing"
  fi

  if [[ -f "$TENANCY_SRC/middleware.py" ]]; then
    pass "middleware.py present"
    if grep -q "TenantResolutionMiddleware" "$TENANCY_SRC/middleware.py"; then
      pass "TenantResolutionMiddleware defined"
    else
      fail "TenantResolutionMiddleware not found in middleware.py"
    fi
  else
    fail "middleware.py missing"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-MT-004: Migration exists
# -----------------------------------------------------------------------
echo "AC-MT-004: Django migration 0001_initial"

if [[ -f "$MIGRATION" ]]; then
  pass "migrations/0001_initial.py exists"
  if grep -q "TenantConfig\|tenantconfig" "$MIGRATION"; then
    pass "Migration references TenantConfig table"
  else
    warn "Migration exists but TenantConfig table not referenced — check migration content"
  fi
else
  fail "migrations/0001_initial.py missing at $MIGRATION"
fi

echo ""

# -----------------------------------------------------------------------
# AC-MT-005: Dockerfile COPY + pip install in apply-patches.sh (all 3 paths)
# -----------------------------------------------------------------------
echo "AC-MT-005: Dockerfile build paths in apply-patches.sh"

if [[ ! -f "$APPLY_PATCHES" ]]; then
  fail "apply-patches.sh missing"
else
  COPY_COUNT=$(grep -c "COPY.*multi-tenancy" "$APPLY_PATCHES" || true)
  PIP_COUNT=$(grep -c "pip install -e.*mereka_tenancy" "$APPLY_PATCHES" || true)

  if [[ "$COPY_COUNT" -ge 3 ]]; then
    pass "multi-tenancy COPY in $COPY_COUNT Dockerfile paths (expected ≥3)"
  elif [[ "$COPY_COUNT" -ge 1 ]]; then
    warn "multi-tenancy COPY only in $COPY_COUNT Dockerfile paths (expected 3: base, assets, worker)"
  else
    fail "multi-tenancy COPY not found in apply-patches.sh Dockerfile paths"
  fi

  if [[ "$PIP_COUNT" -ge 3 ]]; then
    pass "pip install -e mereka_tenancy in $PIP_COUNT Dockerfile paths"
  elif [[ "$PIP_COUNT" -ge 1 ]]; then
    warn "pip install -e mereka_tenancy only in $PIP_COUNT Dockerfile paths (expected 3)"
  else
    fail "pip install -e mereka_tenancy not found in apply-patches.sh"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-MT-001: INSTALLED_APPS patch in apply-patches.sh
# -----------------------------------------------------------------------
echo "AC-MT-001: INSTALLED_APPS patch"

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "'mereka_tenancy' not in INSTALLED_APPS\|mereka_tenancy.*INSTALLED_APPS" "$APPLY_PATCHES"; then
    pass "mereka_tenancy added to INSTALLED_APPS in apply-patches.sh"
  else
    fail "INSTALLED_APPS patch for mereka_tenancy not found in apply-patches.sh"
  fi
fi

if [[ -f "$PLUGIN_PY" ]]; then
  if grep -q "mereka_tenancy.*INSTALLED_APPS\|'mereka_tenancy' not in INSTALLED_APPS" "$PLUGIN_PY"; then
    pass "mereka_tenancy added to INSTALLED_APPS in mereka_lms.py plugin"
  else
    fail "INSTALLED_APPS patch for mereka_tenancy not found in mereka_lms.py"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-MT-002: Middleware patch in apply-patches.sh and plugin
# -----------------------------------------------------------------------
echo "AC-MT-002: TenantResolutionMiddleware patch"

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "TenantResolutionMiddleware" "$APPLY_PATCHES"; then
    pass "TenantResolutionMiddleware insertion in apply-patches.sh"
  else
    fail "TenantResolutionMiddleware not found in apply-patches.sh"
  fi
fi

if [[ -f "$PLUGIN_PY" ]]; then
  if grep -q "TenantResolutionMiddleware" "$PLUGIN_PY"; then
    pass "TenantResolutionMiddleware insertion in mereka_lms.py plugin"
  else
    fail "TenantResolutionMiddleware not found in mereka_lms.py"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# Note: Live verification requires kubectl
# -----------------------------------------------------------------------
echo "[INFO] Source-level checks complete."
echo "[INFO] Live pod verification (requires cluster access):"
echo "  kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell \\"
echo "    -c \"from mereka_tenancy.models import TenantConfig; print('OK')\""
echo "  curl -sI https://academyv2.mereka.io/admin/mereka_tenancy/ | head -3"
echo ""

echo "========================================"
echo "mereka_tenancy: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
