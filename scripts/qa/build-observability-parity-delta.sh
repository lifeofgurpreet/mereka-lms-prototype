#!/usr/bin/env bash
# Build an environment parity delta report from first-class runtime evidence.
#
# Usage:
#   ./scripts/qa/build-observability-parity-delta.sh --env prod --evidence-dir var/ci/parity-prod

set -euo pipefail

ENV_LABEL=""
EVIDENCE_DIR=""
OUT_MD=""
OUT_JSON=""

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/build-observability-parity-delta.sh --env dev|nonprod|prod|custom --evidence-dir <path> [--out-md <path>] [--out-json <path>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_LABEL="${2:-}"
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
      shift 2
      ;;
    --out-json)
      OUT_JSON="${2:-}"
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

if [[ -z "$ENV_LABEL" || -z "$EVIDENCE_DIR" ]]; then
  usage
  exit 1
fi

case "$ENV_LABEL" in
  dev|nonprod) EXPECTED_PROFILE="nonprod" ;;
  prod) EXPECTED_PROFILE="prod" ;;
  custom) EXPECTED_PROFILE="custom" ;;
  *)
    echo "Unsupported --env value: $ENV_LABEL" >&2
    exit 1
    ;;
esac

if [[ -z "$OUT_MD" ]]; then
  OUT_MD="$EVIDENCE_DIR/observability-parity-delta.md"
fi
if [[ -z "$OUT_JSON" ]]; then
  OUT_JSON="$EVIDENCE_DIR/observability-parity-delta.json"
fi

mkdir -p "$(dirname "$OUT_MD")"
mkdir -p "$(dirname "$OUT_JSON")"

PASS=0
FAIL=0
identity_env=""
identity_profile=""
identity_context=""
identity_project=""
RESULTS_FILE="$(mktemp -t obs-parity-delta.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

extract_identity_field() {
  local identity_payload="$1"
  local field="$2"
  local segment
  local key

  IFS=';' read -r -a identity_segments <<< "$identity_payload"
  for segment in "${identity_segments[@]}"; do
    key="${segment%%=*}"
    if [[ "$key" == "$field" ]]; then
      printf '%s' "${segment#*=}"
      return 0
    fi
  done
  return 1
}

record() {
  local status="$1"
  local check_id="$2"
  local msg="$3"
  printf '%s\t%s\t%s\n' "$status" "$check_id" "$msg" >> "$RESULTS_FILE"
  if [[ "$status" == "pass" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

REQUIRED_FILES=(
  "observability-compliance-runtime.json"
  "observability-runtime-verify-runtime.md"
  "observability-correlation-headers-runtime.txt"
  "observability-first-class-runtime-evidence-index.json"
)

if [[ -d "$EVIDENCE_DIR" ]]; then
  record pass "PARITY-001" "Evidence directory exists: $EVIDENCE_DIR"
else
  record fail "PARITY-001" "Evidence directory missing: $EVIDENCE_DIR"
fi

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$EVIDENCE_DIR/$f" ]]; then
    record pass "PARITY-002" "Required artifact present: $f"
  else
    record fail "PARITY-002" "Required artifact missing: $f"
  fi
done

if [[ -f "$EVIDENCE_DIR/observability-correlation-headers-runtime.txt" ]]; then
  if grep -Eq 'PASS|FAIL|WARN' "$EVIDENCE_DIR/observability-correlation-headers-runtime.txt"; then
    record pass "PARITY-009" "Correlation header evidence includes PASS/FAIL/WARN status"
  else
    record fail "PARITY-009" "Correlation header evidence missing PASS/FAIL/WARN status line"
  fi
fi

INDEX_FILE="$EVIDENCE_DIR/observability-first-class-runtime-evidence-index.json"
if [[ -f "$INDEX_FILE" ]]; then
  if command -v jq >/dev/null 2>&1 && jq -e . "$INDEX_FILE" >/dev/null 2>&1; then
    record pass "PARITY-003" "Evidence index is valid JSON"
    identity="$(jq -r '.identity // ""' "$INDEX_FILE")"
    if [[ -n "$identity" ]]; then
      record pass "PARITY-004" "Evidence index contains identity"
      identity_env="$(extract_identity_field "$identity" "env" || true)"
      identity_profile="$(extract_identity_field "$identity" "profile" || true)"
      identity_context="$(extract_identity_field "$identity" "context" || true)"
      identity_project="$(extract_identity_field "$identity" "project" || true)"

      if [[ -n "$identity_context" ]]; then
        record pass "PARITY-007" "Identity context present"
      else
        record fail "PARITY-007" "Identity context missing"
      fi

      if [[ -n "$identity_project" ]]; then
        record pass "PARITY-008" "Identity project present"
      else
        record fail "PARITY-008" "Identity project missing"
      fi

      if [[ "$identity_env" == "$ENV_LABEL" ]]; then
        record pass "PARITY-005" "Identity env matches expected env ($ENV_LABEL)"
      else
        record fail "PARITY-005" "Identity env mismatch: expected=$ENV_LABEL actual=${identity_env:-<empty>}"
      fi

      if [[ "$identity_profile" == "$EXPECTED_PROFILE" ]]; then
        record pass "PARITY-006" "Identity profile matches expected profile ($EXPECTED_PROFILE)"
      else
        record fail "PARITY-006" "Identity profile mismatch: expected=$EXPECTED_PROFILE actual=${identity_profile:-<empty>}"
      fi
    else
      record fail "PARITY-004" "Evidence index identity missing"
    fi
  else
    record fail "PARITY-003" "Evidence index is not valid JSON"
  fi
else
  record fail "PARITY-003" "Evidence index missing: $INDEX_FILE"
fi

TOTAL=$((PASS + FAIL))

{
  echo "# Observability Parity Delta"
  echo ""
  echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- environment: $ENV_LABEL"
  echo "- expected_profile: $EXPECTED_PROFILE"
  echo "- evidence_dir: $EVIDENCE_DIR"
  echo ""
  echo "## Summary"
  echo ""
  echo "- pass: $PASS"
  echo "- fail: $FAIL"
  echo "- total: $TOTAL"
  echo ""
  echo "## Failed checks"
  echo ""
  if awk -F $'\t' '$1=="fail"{exit 0} END{exit 1}' "$RESULTS_FILE"; then
    awk -F $'\t' '$1=="fail"{printf("- %s: %s\n", $2, $3)}' "$RESULTS_FILE"
  else
    echo "- none"
  fi
} > "$OUT_MD"

python3 - "$ENV_LABEL" "$EXPECTED_PROFILE" "$identity_env" "$identity_profile" "$identity_context" "$identity_project" "$PASS" "$FAIL" "$TOTAL" "$RESULTS_FILE" > "$OUT_JSON" <<'PY'
import json
import sys
from datetime import datetime

env_label = sys.argv[1]
expected_profile = sys.argv[2]
identity_env = sys.argv[3]
identity_profile = sys.argv[4]
identity_context = sys.argv[5]
identity_project = sys.argv[6]
passed = int(sys.argv[7])
failed = int(sys.argv[8])
total = int(sys.argv[9])
results_path = sys.argv[10]

checks = []
with open(results_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        status, check_id, message = line.split("\t", 2)
        checks.append({"id": check_id, "status": status, "message": message})

print(json.dumps({
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "environment": env_label,
    "expected_profile": expected_profile,
    "identity": {
        "env": identity_env,
        "profile": identity_profile,
        "context": identity_context,
        "project": identity_project,
    },
    "summary": {
        "pass": passed,
        "fail": failed,
        "total": total
    },
    "checks": checks
}, indent=2))
PY

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
