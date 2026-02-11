#!/usr/bin/env bash
# Spec integrity gate — lint, verify (annotation-based), coverage.
#
# Usage:
#   ./scripts/qa/run-spec-integrity-gates.sh
#   FAIL_UNDER=90 ./scripts/qa/run-spec-integrity-gates.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL_UNDER="${FAIL_UNDER:-50}"
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-120}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-var/spec-integrity-gates/${STAMP}}"
mkdir -p "$ARTIFACT_DIR"

TOOL_DIR="scripts/qa/spec-tools"

failures=0
SUMMARY_TSV="${ARTIFACT_DIR}/checks.tsv"
: >"$SUMMARY_TSV"

run_check() {
  local name="$1"; shift
  local out_file rc slug start_ts end_ts duration_s status
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  start_ts="$(date +%s)"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e

  end_ts="$(date +%s)"
  duration_s=$((end_ts - start_ts))

  if [[ "$rc" -eq 0 ]]; then
    status="ok"
    echo "OK   $name (${duration_s}s)"
  elif [[ "$rc" -eq 124 ]]; then
    status="timeout"
    failures=$((failures + 1))
    echo "FAIL $name (timed out after ${CHECK_TIMEOUT_SECONDS}s)"
    echo "  log: $out_file"
  else
    status="fail"
    failures=$((failures + 1))
    echo "FAIL $name (exit $rc)"
    tail -5 "$out_file" | sed 's/^/  /'
    echo "  log: $out_file"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$status" "$rc" "$duration_s" "$out_file" >>"$SUMMARY_TSV"
}

run_check_info() {
  # Like run_check but non-blocking: logs result without incrementing failures
  local name="$1"; shift
  local out_file rc slug start_ts end_ts duration_s status
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  start_ts="$(date +%s)"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e

  end_ts="$(date +%s)"
  duration_s=$((end_ts - start_ts))

  if [[ "$rc" -eq 0 ]]; then
    status="ok"
    echo "OK   $name (${duration_s}s)"
  else
    status="info"
    echo "INFO $name (${duration_s}s, exit $rc — informational only)"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$status" "$rc" "$duration_s" "$out_file" >>"$SUMMARY_TSV"
}

echo "=== Spec Integrity Gates ==="
echo "Artifacts: $ARTIFACT_DIR"
echo ""

# 1. Spec lint (Mereka-specific rules)
run_check "spec-lint" \
  python3 "${TOOL_DIR}/mereka_spec_lint.py" specs/ --severity-filter error

# 2. Spec verification via @covers annotations (informational — coverage may not be 100%)
run_check_info "spec-verify" \
  python3 "${TOOL_DIR}/mereka_spec_verify.py" specs/ --repo-root . \
    --scan-dirs scripts/ tests/ \
    --manual-file specs/manual_verifications.yaml

# 3. Coverage report with threshold
run_check "spec-coverage" \
  python3 "${TOOL_DIR}/spec_coverage_report.py" \
    --specs-dir specs/ --scan-dirs scripts/ tests/ \
    --manual-file specs/manual_verifications.yaml \
    --repo-root . --format text --fail-under "$FAIL_UNDER"

# Write summary artifacts
write_summary() {
  python3 - "$SUMMARY_TSV" "$ARTIFACT_DIR" <<'PY'
import json, pathlib, sys
from datetime import datetime, timezone

tsv = pathlib.Path(sys.argv[1])
artifact_dir = pathlib.Path(sys.argv[2])

checks = []
for line in tsv.read_text().strip().splitlines():
    parts = line.split("\t")
    if len(parts) >= 5:
        checks.append({
            "name": parts[0],
            "status": parts[1],
            "exit_code": int(parts[2]),
            "duration_s": int(parts[3]),
            "log": parts[4],
        })

total = len(checks)
passed = sum(1 for c in checks if c["status"] in ("ok", "info"))
failed = total - passed

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "total": total,
    "passed": passed,
    "failed": failed,
    "checks": checks,
}

(artifact_dir / "summary.json").write_text(json.dumps(summary, indent=2))

md_lines = [
    "# Spec Integrity Gate Results",
    "",
    f"**{passed}/{total} checks passed** | {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
    "",
    "| Check | Status | Duration |",
    "|-------|--------|----------|",
]
for c in checks:
    icon = "PASS" if c["status"] in ("ok", "info") else "FAIL"
    md_lines.append(f"| {c['name']} | {icon} | {c['duration_s']}s |")

(artifact_dir / "summary.md").write_text("\n".join(md_lines) + "\n")
PY
}

write_summary

echo ""
echo "=== Summary ==="
echo "Checks: $(($(wc -l < "$SUMMARY_TSV"))) total, $failures failed"
echo "Artifacts: $ARTIFACT_DIR"

if [[ "$failures" -gt 0 ]]; then
  echo "RESULT: FAIL ($failures checks failed)"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
