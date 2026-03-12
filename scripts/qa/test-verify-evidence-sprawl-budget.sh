#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/scripts/qa/verify-evidence-sprawl-budget.sh"

tmpdir="$(mktemp -d -t verify-evidence-sprawl-budget.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/scripts/qa" "$tmpdir/verification/manifests"
cp "$SOURCE_SCRIPT" "$tmpdir/scripts/qa/verify-evidence-sprawl-budget.sh"
chmod +x "$tmpdir/scripts/qa/verify-evidence-sprawl-budget.sh"

cd "$tmpdir"
git init -q

mkdir -p docs/archive/verification docs/evidence/operations
cat > verification/manifests/evidence_sprawl_budget.json <<'EOF_BUDGET'
{
  "tracked_evidence_max_files": 5,
  "tracked_evidence_max_bytes": 1000000,
  "tracked_archive_reports_max_files": 0,
  "tracked_archive_reports_max_bytes": 0
}
EOF_BUDGET

cat > docs/evidence/operations/example.md <<'EOF_EVIDENCE'
# Example evidence
EOF_EVIDENCE

git add scripts/qa/verify-evidence-sprawl-budget.sh verification/manifests/evidence_sprawl_budget.json docs/evidence/operations/example.md

if ./scripts/qa/verify-evidence-sprawl-budget.sh >/tmp/test-evidence-budget-pass.log 2>&1; then
  :
else
  echo "Expected baseline evidence budget pass."
  cat /tmp/test-evidence-budget-pass.log
  exit 1
fi

mkdir -p docs/archive/reports
cat > docs/archive/reports/generated.txt <<'EOF_REPORT'
generated report payload
EOF_REPORT
git add docs/archive/reports/generated.txt

if ./scripts/qa/verify-evidence-sprawl-budget.sh >/tmp/test-evidence-budget-fail.log 2>&1; then
  echo "Expected fail when archive report budget is exceeded."
  cat /tmp/test-evidence-budget-fail.log
  exit 1
fi

if ! rg -q "tracked archive report files .* exceeds budget 0" /tmp/test-evidence-budget-fail.log; then
  echo "Expected failure output to mention archive report file budget violation."
  cat /tmp/test-evidence-budget-fail.log
  exit 1
fi

echo "PASS test-verify-evidence-sprawl-budget"
