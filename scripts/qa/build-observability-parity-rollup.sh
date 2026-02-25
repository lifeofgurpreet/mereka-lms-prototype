#!/usr/bin/env bash
# Build a consolidated parity rollup from per-environment parity artifacts.
#
# Usage:
#   ./scripts/qa/build-observability-parity-rollup.sh \
#     --artifacts-dir var/ci/parity-artifacts \
#     --out-md var/ci/observability-parity-rollup.md \
#     --out-json var/ci/observability-parity-rollup.json

set -euo pipefail

ARTIFACTS_DIR=""
OUT_MD=""
OUT_JSON=""
REQUIRE_NO_SKIPS=0

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/build-observability-parity-rollup.sh --artifacts-dir <path> --out-md <path> --out-json <path> [--require-no-skips]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts-dir)
      ARTIFACTS_DIR="${2:-}"
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
    --require-no-skips)
      REQUIRE_NO_SKIPS=1
      shift
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

if [[ -z "$ARTIFACTS_DIR" || -z "$OUT_MD" || -z "$OUT_JSON" ]]; then
  usage
  exit 1
fi

if [[ ! -d "$ARTIFACTS_DIR" ]]; then
  echo "Artifacts directory not found: $ARTIFACTS_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for rollup generation." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_MD")"
mkdir -p "$(dirname "$OUT_JSON")"

envs=(dev nonprod prod)
pass_count=0
fail_count=0
skip_count=0
identity_fail_count=0

ROWS_FILE="$(mktemp -t parity-rollup-rows.XXXXXX)"
trap 'rm -f "$ROWS_FILE"' EXIT

for env_label in "${envs[@]}"; do
  delta_json_path="$(find "$ARTIFACTS_DIR" -type f -name "observability-parity-delta.json" | rg "/parity-${env_label}/" | head -n1 || true)"
  review_md_path="$(find "$ARTIFACTS_DIR" -type f -name "observability-parity-review.md" | rg "/parity-${env_label}/" | head -n1 || true)"
  evidence_identity=""
  identity_env=""
  identity_profile=""
  expected_profile="nonprod"
  if [[ "$env_label" == "prod" ]]; then
    expected_profile="prod"
  fi

  status="missing"
  summary="missing artifact"

  if [[ -n "$delta_json_path" && -f "$delta_json_path" ]]; then
    status_field="$(jq -r '.status // empty' "$delta_json_path")"
    if [[ -n "$status_field" ]]; then
      status="$status_field"
      reason="$(jq -r '.reason // ""' "$delta_json_path")"
      summary="${reason:-skipped}"
    else
      fail_n="$(jq -r '.summary.fail // 0' "$delta_json_path")"
      if [[ "$fail_n" == "0" ]]; then
        status="pass"
      else
        status="fail"
      fi
      summary="$(jq -r '.summary | "pass=\(.pass // 0), fail=\(.fail // 0), total=\(.total // 0)"' "$delta_json_path")"
    fi
  fi

  if [[ -n "$delta_json_path" && -f "$delta_json_path" ]]; then
    index_json_path="$(dirname "${delta_json_path}")/observability-first-class-runtime-evidence-index.json"
    if [[ -f "$index_json_path" ]]; then
    evidence_identity="$(jq -r '.identity // empty' "$index_json_path")"
    identity_env="$(sed -n "s/^env=\\([^;]*\\);.*$/\\1/p" <<<"$evidence_identity")"
    identity_profile="$(sed -n "s/^env=[^;]*;profile=\\([^;]*\\);.*$/\\1/p" <<<"$evidence_identity")"
    if [[ -n "$evidence_identity" ]]; then
      if [[ -z "$identity_env" || "$identity_env" != "$env_label" ]]; then
        status="fail"
        identity_fail_count=$((identity_fail_count + 1))
        summary="identity env mismatch"
      fi
      if [[ -z "$identity_profile" || "$identity_profile" != "$expected_profile" ]]; then
        status="fail"
        identity_fail_count=$((identity_fail_count + 1))
        summary="identity profile mismatch"
      fi
    fi
    fi
  fi

  case "$status" in
    pass) pass_count=$((pass_count + 1)) ;;
    fail|missing) fail_count=$((fail_count + 1)) ;;
    skipped) skip_count=$((skip_count + 1)) ;;
    *) skip_count=$((skip_count + 1)) ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$env_label" \
    "$status" \
    "$summary" \
    "${delta_json_path:-}" \
    "${review_md_path:-}" \
    "${evidence_identity:-}" \
    "${identity_env:-}" \
    "${identity_profile:-}" >> "$ROWS_FILE"
done

{
  echo "# Observability Parity Rollup"
  echo ""
  echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- require_no_skips: $REQUIRE_NO_SKIPS"
  echo "- pass: $pass_count"
  echo "- fail: $fail_count"
  echo "- skipped: $skip_count"
  echo ""
  echo "## Environment status"
  echo ""
  echo "| Environment | Status | Summary |"
  echo "|---|---|---|"
  while IFS=$'\t' read -r env_label status summary _delta _review; do
    echo "| $env_label | $status | $summary |"
  done < "$ROWS_FILE"
} > "$OUT_MD"

python3 - "$ROWS_FILE" "$pass_count" "$fail_count" "$skip_count" "$identity_fail_count" "$REQUIRE_NO_SKIPS" > "$OUT_JSON" <<'PY'
import json
from datetime import datetime, timezone
import sys
from datetime import datetime

rows_file = sys.argv[1]
pass_count = int(sys.argv[2])
fail_count = int(sys.argv[3])
skip_count = int(sys.argv[4])
identity_fail_count = int(sys.argv[5])
require_no_skips = bool(int(sys.argv[6]))

envs = []
with open(rows_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        env_label, status, summary, delta_path, review_path, evidence_identity, identity_env, identity_profile = line.split("\t", 8)
        envs.append({
            "environment": env_label,
            "status": status,
            "summary": summary,
            "delta_json": delta_path,
            "review_md": review_path,
            "identity": evidence_identity,
            "identity_env": identity_env,
            "identity_profile": identity_profile,
        })

print(json.dumps({
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "require_no_skips": require_no_skips,
    "summary": {
        "pass": pass_count,
        "fail": fail_count,
        "skipped": skip_count,
        "identity_fail_count": identity_fail_count,
        "total": len(envs),
    },
    "environments": envs,
}, indent=2))
PY

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi

if [[ "$REQUIRE_NO_SKIPS" == "1" && "$skip_count" -gt 0 ]]; then
  exit 1
fi

exit 0
