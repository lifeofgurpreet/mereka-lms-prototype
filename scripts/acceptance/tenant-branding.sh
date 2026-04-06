#!/usr/bin/env bash
# Canonical acceptance front door for the tenant-branding lane.
#
# Proves tenant visual identity: MFE config palette, authn shell branding
# (eyebrow/brand/hero), theme CSS bundles, logo assets, and browser DOM
# contract (when Playwright is available).
#
# Wraps the existing verify-tenant-visual-contract.sh oracle and adds
# schema-valid proof bundle output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENVIRONMENT="dev"
TENANT_FILTER=""
OUTPUT_DIR=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/acceptance/tenant-branding.sh [OPTIONS]

Options:
  --env <production|staging|dev>  Environment to verify
  --tenant <slug>                 Restrict to one tenant
  --output-dir <path>             Override proof bundle path
  --dry-run                       Emit the plan without executing checks
  -h, --help                      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="${2:?--env requires a value}"; shift 2 ;;
    --tenant) TENANT_FILTER="${2:?--tenant requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ENVIRONMENT" in
  prod) ENVIRONMENT="prod" ;;  # visual contract uses "prod" not "production"
  production) ENVIRONMENT="prod" ;;
  staging|dev) ;;
  *)
    echo "Invalid --env: $ENVIRONMENT" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/var/acceptance/tenant-branding/${ENVIRONMENT}/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUTPUT_DIR"

SUMMARY_TSV="$OUTPUT_DIR/checks.tsv"
SUMMARY_JSON="$OUTPUT_DIR/summary.json"
GENERATED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
: >"$SUMMARY_TSV"

VISUAL_LOG="$OUTPUT_DIR/visual-contract.log"
EVIDENCE_DIR="$OUTPUT_DIR/evidence"
CHECK_SCOPE="$ENVIRONMENT${TENANT_FILTER:+:$TENANT_FILTER}"
mkdir -p "$EVIDENCE_DIR"

if [[ "$DRY_RUN" == "1" ]]; then
  {
    printf "DRY RUN: would execute verify-tenant-visual-contract.sh --env %s" "$ENVIRONMENT"
    if [[ -n "$TENANT_FILTER" ]]; then
      printf " --tenant %s" "$TENANT_FILTER"
    fi
    printf " --evidence-dir %s\n" "$EVIDENCE_DIR"
  } >"$VISUAL_LOG"
  printf "visual-contract:%s\tplanned\t0\t%s\n" "$CHECK_SCOPE" "$VISUAL_LOG" >>"$SUMMARY_TSV"
  VISUAL_RC=0
else
  VISUAL_ARGS=(
    --env "$ENVIRONMENT"
    --evidence-dir "$EVIDENCE_DIR"
  )
  if [[ -n "$TENANT_FILTER" ]]; then
    VISUAL_ARGS+=(--tenant "$TENANT_FILTER")
  fi
  if bash "$REPO_ROOT/scripts/qa/verify-tenant-visual-contract.sh" \
    "${VISUAL_ARGS[@]}" \
    >"$VISUAL_LOG" 2>&1; then
    VISUAL_RC=0
  else
    VISUAL_RC=$?
  fi
  printf "visual-contract:%s\t%s\t%s\t%s\n" \
    "$CHECK_SCOPE" \
    "$(if [[ "$VISUAL_RC" -eq 0 ]]; then echo pass; else echo fail; fi)" \
    "$VISUAL_RC" \
    "$VISUAL_LOG" \
    >>"$SUMMARY_TSV"
fi

# Extract per-domain pass/fail from the visual contract log
DOMAIN_RESULTS=""
if [[ -f "$VISUAL_LOG" ]]; then
  DOMAIN_RESULTS="$(python3 - "$VISUAL_LOG" "$SUMMARY_TSV" "$ENVIRONMENT" <<'PY'
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
tsv_path = Path(sys.argv[2])
env = sys.argv[3]

log_text = log_path.read_text(encoding="utf-8")

# Extract per-domain summary from the visual contract output
# Pattern: "| domain | STATUS | PASS=N FAIL=N WARN=N |"
domain_pattern = re.compile(r'\|\s*(\S+)\s*\|\s*(PASS|WARN|FIX|FAIL)\s*\|\s*PASS=(\d+)\s+FAIL=(\d+)\s+WARN=(\d+)')
results = []
for match in domain_pattern.finditer(log_text):
    domain, status, passes, fails, warns = match.groups()
    check_status = "pass" if int(fails) == 0 else "fail"
    with tsv_path.open("a", encoding="utf-8") as f:
        f.write(f"branding:{domain}\t{check_status}\t{fails}\t{sys.argv[1]}\n")
    results.append(f"{domain}:{check_status}({passes}P/{fails}F/{warns}W)")

print(" ".join(results) if results else "no-domain-results")
PY
  )"
fi

# Count results
PASS_COUNT=$(awk -F'\t' '$2=="pass"' "$SUMMARY_TSV" | wc -l | tr -d ' ')
FAIL_COUNT=$(awk -F'\t' '$2=="fail"' "$SUMMARY_TSV" | wc -l | tr -d ' ')
SKIP_COUNT=$(awk -F'\t' '$2=="skip"' "$SUMMARY_TSV" | wc -l | tr -d ' ')

MODE="execute"
[[ "$DRY_RUN" == "1" ]] && MODE="dry-run"

VERDICT="pass"
[[ "$FAIL_COUNT" -gt 0 ]] && VERDICT="fail"

# Extract totals from visual contract log
TOTAL_PASS=$(grep -oP 'PASS=\K\d+' "$VISUAL_LOG" 2>/dev/null | tail -1 || echo 0)
TOTAL_FAIL=$(grep -oP 'FAIL=\K\d+' "$VISUAL_LOG" 2>/dev/null | tail -1 || echo 0)
TOTAL_WARN=$(grep -oP 'WARN=\K\d+' "$VISUAL_LOG" 2>/dev/null | tail -1 || echo 0)

python3 - "$SUMMARY_JSON" "$VERDICT" "$FAIL_COUNT" "$PASS_COUNT" "$SKIP_COUNT" \
  "$ENVIRONMENT" "$MODE" "$GENERATED_AT_UTC" "$OUTPUT_DIR" "$SUMMARY_TSV" "$TENANT_FILTER" \
  "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_WARN" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
verdict = sys.argv[2]
fail_count = int(sys.argv[3])
pass_count = int(sys.argv[4])
skip_count = int(sys.argv[5])
environment = sys.argv[6]
mode = sys.argv[7]
generated_at = sys.argv[8]
output_dir = sys.argv[9]
tsv_path = sys.argv[10]
tenant_filter = sys.argv[11] or None
total_pass = int(sys.argv[12]) if sys.argv[12] else 0
total_fail = int(sys.argv[13]) if sys.argv[13] else 0
total_warn = int(sys.argv[14]) if sys.argv[14] else 0

checks = []
for line in Path(tsv_path).read_text(encoding="utf-8").strip().splitlines():
    parts = line.split("\t")
    if len(parts) >= 4:
        checks.append({
            "name": parts[0],
            "status": parts[1],
            "exit_code": int(parts[2]),
            "log": parts[3],
        })

summary = {
    "schema_version": "tenant-branding-proof/v1",
    "generated_at_utc": generated_at,
    "lane": "tenant-branding",
    "environment": environment,
    "tenant_filter": tenant_filter,
    "mode": mode,
    "verdict": {
        "status": verdict,
        "failed_checks": fail_count,
        "passed_checks": pass_count,
        "skipped_checks": skip_count,
    },
    "visual_contract_totals": {
        "pass": total_pass,
        "fail": total_fail,
        "warn": total_warn,
    },
    "artifacts": {
        "output_dir": output_dir,
        "checks_tsv": tsv_path,
        "summary_json": str(summary_path),
        "evidence_dir": output_dir + "/evidence",
    },
    "checks": checks,
}

summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY

echo "$SUMMARY_JSON"
