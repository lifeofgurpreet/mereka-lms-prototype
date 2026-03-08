#!/usr/bin/env bash
# verify-dev-runtime-proof.sh — Post-deploy runtime proof for dev tenants
#
# Runs immediately after new images are deployed to mereka-lms-dev.
# Verifies image truth, module presence, host acceptance, SiteConfiguration,
# MFE config isolation, cookie domain scoping, and auth redirect routing.
#
# Usage:
#   scripts/tenants/verify-dev-runtime-proof.sh [--namespace NS] [--dry-run] [--output-dir DIR]
#
# Writes:
#   var/proof/dev-runtime-proof.json   (machine-readable consolidated proof)
#
# Exit codes:
#   0  all critical (P0) checks passed
#   1  one or more critical checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
OUTPUT_DIR="${REPO_ROOT}/var/proof"
DRY_RUN=false
CURL_TIMEOUT=15

# ── Arg parsing ───────────────────────────────────────────────────────────────
# Note: --namespace may override the env file default; parse before sourcing.
_NS_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)  _NS_OVERRIDE="${2:?--namespace requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--dry-run] [--output-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Load environment constants ────────────────────────────────────────────────
# shellcheck source=env/dev.env
source "${SCRIPT_DIR}/env/dev.env"

# Allow --namespace override after env file sets its default
[[ -n "$_NS_OVERRIDE" ]] && NAMESPACE="$_NS_OVERRIDE"

mkdir -p "$OUTPUT_DIR"

# ── Dry-run stub ──────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "=== DRY RUN MODE — no live cluster calls will be made ==="
  echo "Namespace : $NAMESPACE"
  echo "Output dir: $OUTPUT_DIR"
  echo "Tenants   : ${#TENANTS[@]}"
  for t in "${TENANTS[@]}"; do
    IFS=: read -r slug lms _dr_studio mfe _dr_cd <<< "$t"
    printf "  %-20s  lms=%-45s  mfe=%s\n" "$slug" "$lms" "$mfe"
  done
  echo ""
  echo "Dry-run complete — nothing written."
  exit 0
fi

# ── Prerequisite: kubectl ─────────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH" >&2
  exit 1
fi

# ── Discover LMS pod ─────────────────────────────────────────────────────────
echo "=== verify-dev-runtime-proof: ns=$NAMESPACE ==="
echo "Timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Output    : $OUTPUT_DIR/dev-runtime-proof.json"
echo ""

# shellcheck source=lib/runtime-proof-common.sh
source "${SCRIPT_DIR}/lib/runtime-proof-common.sh"

LMS_POD="$(_find_ready_pod lms)"
if [[ -z "$LMS_POD" ]]; then
  echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2
  exit 1
fi
echo "LMS pod   : $LMS_POD"

CMS_POD="$(_find_ready_pod cms)"
MFE_POD="$(_find_ready_pod mfe)"
echo "CMS pod   : ${CMS_POD:-(none)}"
echo "MFE pod   : ${MFE_POD:-(none)}"
echo ""

# ── Run all proof sections ────────────────────────────────────────────────────
run_proof "$LMS_POD"
