#!/usr/bin/env bash
# Verify observability evidence identity consistency within an artifact directory.
#
# Usage:
#   ./scripts/qa/verify-observability-evidence-identity.sh --dir var/ci
#   ./scripts/qa/verify-observability-evidence-identity.sh --dir var/dr-evidence/<stamp>/observability-runtime

set -euo pipefail

DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/observability-status.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-observability-evidence-identity.sh --dir <path>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$DIR" ]]; then
  usage
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "Evidence directory not found: $DIR" >&2
  exit 1
fi

failures=0

extract_md_identity() {
  local f="$1"
  grep -E '^- evidence_identity:' "$f" | head -n1 | sed 's/^- evidence_identity: //'
}

check_runtime_bundle() {
  local index="$DIR/observability-first-class-runtime-evidence-index.json"
  local compliance_md="$DIR/observability-compliance-runtime.md"
  local correlation_txt="$DIR/observability-correlation-headers-runtime.txt"
  local verifier_md="$DIR/observability-runtime-verify-runtime.md"
  local preflight_md="$DIR/observability-runtime-preflight.md"

  if [[ ! -f "$index" ]]; then
    return 0
  fi

  local index_identity
  index_identity="$(jq -r '.identity' "$index")"
  if [[ -z "$index_identity" || "$index_identity" == "null" ]]; then
    echo "FAIL runtime: index identity missing in $index"
    failures=$((failures + 1))
    return 0
  fi

  if [[ -f "$compliance_md" ]]; then
    local compliance_identity
    compliance_identity="$(extract_md_identity "$compliance_md")"
    if [[ "$index_identity" != "$compliance_identity" ]]; then
      echo "FAIL runtime: compliance identity mismatch"
      echo "  index:      $index_identity"
      echo "  compliance: $compliance_identity"
      failures=$((failures + 1))
    fi
  fi

  if [[ -f "$verifier_md" ]]; then
    local verifier_identity
    verifier_identity="$(extract_md_identity "$verifier_md")"
    if [[ "$index_identity" != "$verifier_identity" ]]; then
      echo "FAIL runtime: verifier identity mismatch"
      echo "  index:    $index_identity"
      echo "  verifier: $verifier_identity"
      failures=$((failures + 1))
    fi
  fi

  if [[ -f "$preflight_md" ]]; then
    local preflight_identity
    preflight_identity="$(extract_md_identity "$preflight_md")"
    if [[ "$index_identity" != "$preflight_identity" ]]; then
      echo "FAIL runtime: preflight identity mismatch"
      echo "  index:     $index_identity"
      echo "  preflight: $preflight_identity"
      failures=$((failures + 1))
    fi
  fi

  if [[ -f "$correlation_txt" ]]; then
    if ! has_observability_status_line "$correlation_txt"; then
      echo "FAIL runtime: correlation evidence missing PASS/FAIL/WARN status lines in $correlation_txt"
      failures=$((failures + 1))
    fi
  else
    echo "FAIL runtime: required correlation header evidence file missing: $correlation_txt"
    failures=$((failures + 1))
  fi

  echo "OK   runtime evidence identity"
}

check_local_bundle() {
  local index="$DIR/observability-first-class-local-evidence-index.json"
  local compliance_md="$DIR/observability-compliance-local.md"

  if [[ ! -f "$index" ]]; then
    return 0
  fi

  local index_identity
  index_identity="$(jq -r '.identity' "$index")"
  if [[ -z "$index_identity" || "$index_identity" == "null" ]]; then
    echo "FAIL local: index identity missing in $index"
    failures=$((failures + 1))
    return 0
  fi

  if [[ -f "$compliance_md" ]]; then
    local compliance_identity
    compliance_identity="$(extract_md_identity "$compliance_md")"
    if [[ "$index_identity" != "$compliance_identity" ]]; then
      echo "FAIL local: compliance identity mismatch"
      echo "  index:      $index_identity"
      echo "  compliance: $compliance_identity"
      failures=$((failures + 1))
    fi
  fi

  echo "OK   local evidence identity"
}

check_runtime_bundle
check_local_bundle

if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures identity checks failed)" >&2
  exit 1
fi

echo "OK"
