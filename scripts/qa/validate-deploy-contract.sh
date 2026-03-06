#!/usr/bin/env bash
# validate-deploy-contract.sh — master deploy package contract gate
#
# Runs all sub-gates in order and fails fast on any blocking failure.
# Intended for CI (static-validation job) and local pre-commit checks.
#
# Usage:
#   scripts/qa/validate-deploy-contract.sh           # Standard mode (checks 4+5 are WARN)
#   scripts/qa/validate-deploy-contract.sh --strict  # Strict mode (all checks are FAIL)
#
# Exit codes:
#   0  — All checks passed (or all non-strict checks passed)
#   1  — One or more checks failed
#
# Checks:
#   1. No private key material in deploy tree
#   2. No generated Python artifacts in deploy tree
#   3. No mutable or placeholder images in deploy tree
#   4. No environment-specific domains in base/ [WARN without --strict]
#   5. No upward path traversal in kustomize files [WARN without --strict]
#   6. Base kustomize renders successfully
#   7. Local overlay kustomize renders successfully
#   8. No cluster-scoped resources in base rendered output [WARN always]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QA_DIR="${REPO_ROOT}/scripts/qa"

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Argument parsing ──────────────────────────────────────────────────────────
STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--strict]"
      echo ""
      echo "  --strict   Treat checks 4 and 5 as blocking failures (default: WARN)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $(basename "$0") [--strict]" >&2
      exit 1
      ;;
  esac
done

# ── Tracking ──────────────────────────────────────────────────────────────────
FAILURES=()
WARNINGS=()
PASSES=()

section() {
  echo ""
  echo -e "${BLUE}${BOLD}══ $1 ══${NC}"
}

pass_check() {
  local name="$1"
  echo -e "  ${GREEN}PASS${NC}  $name"
  PASSES+=("$name")
}

fail_check() {
  local name="$1"
  echo -e "  ${RED}FAIL${NC}  $name"
  FAILURES+=("$name")
}

warn_check() {
  local name="$1"
  local reason="$2"
  echo -e "  ${YELLOW}WARN${NC}  $name — $reason"
  WARNINGS+=("$name")
}

# Runs a sub-script and captures its exit code without triggering set -e
run_sub() {
  local script="$1"
  shift
  local rc=0
  "$script" "$@" || rc=$?
  return $rc
}

# ── CHECK 1: No private key material ─────────────────────────────────────────
section "CHECK 1: No private key material in deploy tree"
echo "  Scope: deploy/k8s/"
if run_sub "${QA_DIR}/no_private_key_material.sh" "${REPO_ROOT}/deploy/k8s"; then
  pass_check "no-private-key-material"
else
  fail_check "no-private-key-material"
  echo -e "  ${RED}Blocking failure — stopping immediately.${NC}"
  echo ""
  echo -e "${RED}${BOLD}DEPLOY CONTRACT VIOLATED${NC}: private key material in deploy tree"
  exit 1
fi

# ── CHECK 2: No generated Python artifacts ────────────────────────────────────
section "CHECK 2: No generated Python artifacts in deploy tree"
echo "  Scope: deploy/k8s/"
if run_sub "${QA_DIR}/no_generated_python_artifacts.sh" "${REPO_ROOT}/deploy/k8s"; then
  pass_check "no-generated-python-artifacts"
else
  fail_check "no-generated-python-artifacts"
fi

# ── CHECK 3: No mutable or placeholder images ─────────────────────────────────
section "CHECK 3: No mutable or placeholder images"
echo "  Scope: deploy/k8s/"
echo "  Note: :latest tags and placeholder/ prefixes are never acceptable."
if run_sub "${QA_DIR}/no_mutable_or_placeholder_images.sh" "${REPO_ROOT}/deploy/k8s"; then
  pass_check "no-mutable-or-placeholder-images"
else
  fail_check "no-mutable-or-placeholder-images"
fi

# ── CHECK 4: No environment domains in base ───────────────────────────────────
section "CHECK 4: No environment-specific domains in base/"
echo "  Scope: deploy/k8s/base/"
if [[ $STRICT -eq 1 ]]; then
  echo "  Mode: STRICT (failure blocks)"
  if run_sub "${QA_DIR}/no_environment_domains_in_base.sh" "${REPO_ROOT}/deploy/k8s/base"; then
    pass_check "no-environment-domains-in-base"
  else
    fail_check "no-environment-domains-in-base"
  fi
else
  echo "  Mode: WARN (use --strict to make blocking; expected to fail until PR-04 lands)"
  if run_sub "${QA_DIR}/no_environment_domains_in_base.sh" "${REPO_ROOT}/deploy/k8s/base"; then
    pass_check "no-environment-domains-in-base"
  else
    warn_check "no-environment-domains-in-base" "environment domains in base/ (non-blocking until PR-04)"
  fi
fi

# ── CHECK 5: No upward path traversal ─────────────────────────────────────────
section "CHECK 5: No upward path traversal in kustomize files"
echo "  Scope: deploy/k8s/"
if [[ $STRICT -eq 1 ]]; then
  echo "  Mode: STRICT (failure blocks)"
  if run_sub "${QA_DIR}/no_upward_relative_paths_in_kustomize.sh" "${REPO_ROOT}/deploy/k8s"; then
    pass_check "no-upward-relative-paths"
  else
    fail_check "no-upward-relative-paths"
  fi
else
  echo "  Mode: WARN (use --strict to make blocking; expected to fail until PR-04 lands)"
  if run_sub "${QA_DIR}/no_upward_relative_paths_in_kustomize.sh" "${REPO_ROOT}/deploy/k8s"; then
    pass_check "no-upward-relative-paths"
  else
    warn_check "no-upward-relative-paths" "upward traversal paths in kustomize (non-blocking until PR-04)"
  fi
fi

# ── CHECK 6: Base kustomize renders ───────────────────────────────────────────
section "CHECK 6: Base kustomize renders"
echo "  Path: deploy/k8s/base/"
if ! command -v kubectl &>/dev/null; then
  warn_check "base-kustomize-render" "kubectl not found — skipping"
elif kubectl kustomize "${REPO_ROOT}/deploy/k8s/base/" >/dev/null 2>&1; then
  pass_check "base-kustomize-render"
else
  echo "  Render error output:"
  kubectl kustomize "${REPO_ROOT}/deploy/k8s/base/" 2>&1 | sed 's/^/    /' || true
  fail_check "base-kustomize-render"
fi

# ── CHECK 7: Local overlay renders ────────────────────────────────────────────
section "CHECK 7: Local overlay kustomize renders"
echo "  Path: deploy/k8s/overlays/local/"
if ! command -v kubectl &>/dev/null; then
  warn_check "local-overlay-kustomize-render" "kubectl not found — skipping"
elif [[ ! -d "${REPO_ROOT}/deploy/k8s/overlays/local" ]]; then
  warn_check "local-overlay-kustomize-render" "overlay directory not found — skipping"
elif kubectl kustomize "${REPO_ROOT}/deploy/k8s/overlays/local/" >/dev/null 2>&1; then
  pass_check "local-overlay-kustomize-render"
else
  echo "  Render error output:"
  kubectl kustomize "${REPO_ROOT}/deploy/k8s/overlays/local/" 2>&1 | sed 's/^/    /' || true
  fail_check "local-overlay-kustomize-render"
fi

# ── CHECK 8: No cluster-scoped resources in base (informational WARN) ─────────
section "CHECK 8: No cluster-scoped resources in base rendered output [WARN]"
echo "  This check is always informational — cluster-scoped resources in base"
echo "  are sometimes legitimate (e.g. Namespace), but ClusterRole/ClusterPolicy"
echo "  warrant review."
CLUSTER_SCOPED_TYPES=(ClusterRole ClusterRoleBinding ClusterPolicy ClusterSecretStore)
if ! command -v kubectl &>/dev/null; then
  warn_check "no-cluster-scoped-in-base" "kubectl not found — skipping"
else
  rendered_base=""
  if rendered_base=$(kubectl kustomize "${REPO_ROOT}/deploy/k8s/base/" 2>/dev/null); then
    found_types=()
    for kind in "${CLUSTER_SCOPED_TYPES[@]}"; do
      if echo "$rendered_base" | grep -qE "^kind:[[:space:]]+${kind}$"; then
        found_types+=("$kind")
      fi
    done
    if [[ ${#found_types[@]} -gt 0 ]]; then
      warn_check "no-cluster-scoped-in-base" "cluster-scoped types found: ${found_types[*]} — review if intentional"
    else
      pass_check "no-cluster-scoped-in-base"
    fi
  else
    warn_check "no-cluster-scoped-in-base" "base did not render — skipping cluster-scope check"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}${BOLD}══ DEPLOY CONTRACT SUMMARY ══${NC}"
echo ""

if [[ ${#PASSES[@]} -gt 0 ]]; then
  echo -e "  ${GREEN}PASS${NC} (${#PASSES[@]}):"
  for name in "${PASSES[@]}"; do
    echo "    - $name"
  done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo ""
  echo -e "  ${YELLOW}WARN${NC} (${#WARNINGS[@]}) — non-blocking:"
  for name in "${WARNINGS[@]}"; do
    echo "    - $name"
  done
fi

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo -e "  ${RED}FAIL${NC} (${#FAILURES[@]}) — blocking:"
  for name in "${FAILURES[@]}"; do
    echo "    - $name"
  done
  echo ""
  echo -e "${RED}${BOLD}Result: FAIL${NC} — ${#FAILURES[@]} check(s) failed"
  if [[ $STRICT -eq 0 ]]; then
    echo "  Tip: run with --strict to also block on checks 4 and 5."
  fi
  exit 1
fi

echo ""
if [[ $STRICT -eq 1 ]]; then
  echo -e "${GREEN}${BOLD}Result: PASS${NC} (strict mode — all ${#PASSES[@]} checks passed)"
else
  echo -e "${GREEN}${BOLD}Result: PASS${NC} — all ${#PASSES[@]} checks passed"
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "  (${#WARNINGS[@]} non-blocking warning(s) — run with --strict to enforce)"
  fi
fi
