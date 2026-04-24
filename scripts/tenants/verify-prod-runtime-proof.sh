#!/usr/bin/env bash
# verify-prod-runtime-proof.sh — Post-deploy runtime proof for production tenants
#
# This lane is distinct from parked-state verification. Use it only when
# production is intentionally active and serving traffic.
#
# Usage:
#   scripts/tenants/verify-prod-runtime-proof.sh [--namespace NS] [--dry-run] [--output-dir DIR] [--release-object-json PATH]
#
# Writes:
#   var/proof/prod-runtime-proof.json
#
# Exit codes:
#   0  all critical (P0) checks passed
#   1  one or more critical checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUTPUT_DIR="${REPO_ROOT}/var/proof"
DRY_RUN=false
CURL_TIMEOUT=15
RELEASE_OBJECT_JSON=""
RELEASE_OBJECT_ID=""

_NS_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)  _NS_OVERRIDE="${2:?--namespace requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --release-object-json) RELEASE_OBJECT_JSON="${2:?--release-object-json requires a value}"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--dry-run] [--output-dir DIR] [--release-object-json PATH]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# shellcheck source=env/prod.env
source "${SCRIPT_DIR}/env/prod.env"

[[ -n "$_NS_OVERRIDE" ]] && NAMESPACE="$_NS_OVERRIDE"

if [[ -n "$RELEASE_OBJECT_JSON" ]]; then
  if [[ ! -f "$RELEASE_OBJECT_JSON" ]]; then
    echo "ERROR: release object not found: $RELEASE_OBJECT_JSON" >&2
    exit 1
  fi
  RELEASE_OBJECT_JSON="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$RELEASE_OBJECT_JSON")"
  RELEASE_OBJECT_ID="$(
    python3 - "$RELEASE_OBJECT_JSON" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
release_id = str(payload.get("release_id", "")).strip()
if not release_id:
    raise SystemExit("release object missing release_id")
print(release_id)
PY
  )"
fi

mkdir -p "$OUTPUT_DIR"

if $DRY_RUN; then
  echo "=== DRY RUN MODE — no live cluster calls will be made ==="
  echo "Namespace : $NAMESPACE"
  echo "Output dir: $OUTPUT_DIR"
  [[ -n "$RELEASE_OBJECT_ID" ]] && echo "Release ID: $RELEASE_OBJECT_ID"
  echo "Tenants   : ${#TENANTS[@]}"
  for t in "${TENANTS[@]}"; do
    IFS=: read -r slug lms _dr_studio mfe _dr_cd <<< "$t"
    printf "  %-20s  lms=%-45s  mfe=%s\n" "$slug" "$lms" "$mfe"
  done
  echo ""
  echo "Dry-run complete — nothing written."
  exit 0
fi

if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH" >&2
  exit 1
fi

echo "=== verify-prod-runtime-proof: ns=$NAMESPACE ==="
echo "Timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Output    : $OUTPUT_DIR/prod-runtime-proof.json"
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

run_proof "$LMS_POD"
