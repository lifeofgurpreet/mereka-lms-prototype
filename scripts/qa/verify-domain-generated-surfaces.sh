#!/usr/bin/env bash
# verify-domain-generated-surfaces.sh — Ensures all domain-derived generated
# artifacts are current (not stale relative to tenant-registry.yaml).
#
# Runs each domain generator in --check mode. Generators that don't exist yet
# are reported as WARN (not FAIL) to allow incremental rollout.
#
# This is a static repo check — no running cluster required.
#
# Usage: ./scripts/qa/verify-domain-generated-surfaces.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/lib.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT" == "1" ]]; then
    FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} (strict) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

printf "${BLUE}=== Domain Generated Surfaces Gate ===${NC}\n\n"

# List of domain generators with their --check mode
GENERATORS=(
  "scripts/domains/generate_domain_authority_matrix.py"
  "scripts/domains/generate_config_domains.py"
  "scripts/domains/generate_domain_env.py"
)

LABELS=(
  "Domain authority matrix"
  "Config domains"
  "Domain env"
)

for i in "${!GENERATORS[@]}"; do
  gen="${GENERATORS[$i]}"
  label="${LABELS[$i]}"
  gen_path="$REPO_ROOT/$gen"

  printf "${BLUE}── ${label} (${gen}) ──${NC}\n"

  if [[ ! -f "$gen_path" ]]; then
    do_warn "$label generator not found: $gen (may be added in a later PR)"
    continue
  fi

  if [[ ! -r "$gen_path" ]]; then
    do_fail "$label generator not readable: $gen"
    continue
  fi

  # Run in --check mode
  output=""
  if output=$(python3 "$gen_path" --check 2>&1); then
    do_pass "$label: generated files are current"
  else
    do_fail "$label: generated files are stale or check failed"
    # Print first few lines of output for context
    if [[ -n "$output" ]]; then
      echo "  output: $(echo "$output" | head -5)"
    fi
  fi
done

# ── Active overlay parity ────────────────────────────────────────────────
# Verify that active Kustomize overlay patches match the generated output.
# This ensures CI cannot pass while deployed patches drift from the registry.

printf "\n${BLUE}── Active overlay parity ──${NC}\n"

declare -A OVERLAY_PARITY
OVERLAY_PARITY["local"]="deploy/k8s/overlays/local/patches/domain-env.yaml:generated/domains/local/domain-env.yaml"
OVERLAY_PARITY["rke2-nonprod"]="deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml:generated/domains/dev/domain-env.yaml"
OVERLAY_PARITY["staging"]="deploy/k8s/overlays/staging/patches/domain-env.yaml:generated/domains/staging/domain-env.yaml"

for env_name in local rke2-nonprod staging; do
  pair="${OVERLAY_PARITY[$env_name]}"
  active="${REPO_ROOT}/${pair%%:*}"
  generated="${REPO_ROOT}/${pair##*:}"

  if [[ ! -f "$active" ]]; then
    do_warn "$env_name overlay patch not found: ${pair%%:*}"
    continue
  fi
  if [[ ! -f "$generated" ]]; then
    do_warn "$env_name generated patch not found: ${pair##*:}"
    continue
  fi

  # Strip leading comment lines (GENERATED header) from the active file
  # for comparison, since the generated copy doesn't have them
  active_body=$(grep -v '^# GENERATED\|^# Regenerate:' "$active")
  generated_body=$(cat "$generated")

  if [[ "$active_body" == "$generated_body" ]]; then
    do_pass "$env_name overlay patch matches generated output"
  else
    do_fail "$env_name overlay patch differs from generated output (${pair%%:*} vs ${pair##*:})"
    diff <(echo "$active_body") <(echo "$generated_body") | head -10 || true
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}=== Domain Generated Surfaces: ${PASS} PASS / ${FAIL} FAIL / ${WARN} WARN ===${NC}"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "\n${RED}GATE FAILED${NC} — $FAIL check(s) failed."
  exit 1
fi

echo -e "\n${GREEN}GATE PASSED${NC}"
exit 0
