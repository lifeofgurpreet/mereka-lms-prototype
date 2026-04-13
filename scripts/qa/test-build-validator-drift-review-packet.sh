#!/usr/bin/env bash
# Lightweight self-test for build-validator-drift-review-packet.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/qa/build-validator-drift-review-packet.sh"
TMP_DIR="$(mktemp -d)"
TMP_FIXTURE_DIR="$TMP_DIR/tmp-build-validator-drift-review-packet"
TMP_FIXTURE_FILE="$TMP_FIXTURE_DIR/verify-repo-structure.sh"

cleanup() {
  rm -f "$TMP_FIXTURE_FILE"
  rmdir "$TMP_FIXTURE_DIR" 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OUT_DIR="$TMP_DIR/review-default"
"$BUILD_SCRIPT" --out-dir "$OUT_DIR" >/dev/null

required_files=(
  "$OUT_DIR/README.md"
  "$OUT_DIR/01_scope.md"
  "$OUT_DIR/02_claims.json"
  "$OUT_DIR/03_canonical_script_catalog.json"
  "$OUT_DIR/04_duplicate_overlap_clusters.json"
  "$OUT_DIR/05_ci_reachability.json"
  "$OUT_DIR/06_mutability_blast_radius.json"
  "$OUT_DIR/07_environment_taxonomy.txt"
  "$OUT_DIR/08_generated_artifact_leakage.txt"
  "$OUT_DIR/09_seeded_defect_results.txt"
  "$OUT_DIR/10_docs_truth_scan.txt"
  "$OUT_DIR/11_open_risks.json"
  "$OUT_DIR/12_what_this_review_does_not_prove.md"
)

for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || { echo "FAIL missing: $f" >&2; exit 1; }
done

grep -q 'run_seeded_defects=0' "$OUT_DIR/09_seeded_defect_results.txt"
grep -q 'SKIP seeded-defect execution' "$OUT_DIR/09_seeded_defect_results.txt"

python3 - "$OUT_DIR/05_ci_reachability.json" <<'PY'
from __future__ import annotations
import json
import sys
from pathlib import Path

reachability = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
rows = reachability.get("verify_scripts", [])
if not rows:
    raise SystemExit("FAIL reachability map has no verify_scripts entries")

sample = rows[0]
required = {
    "status",
    "workflow_refs",
    "multisite_gate",
    "manual_runbook_refs",
    "reachable_via_script_chain",
    "reachable_any",
}
missing = sorted(required.difference(sample))
if missing:
    raise SystemExit(f"FAIL reachability entry missing keys: {', '.join(missing)}")
PY

mkdir -p "$TMP_FIXTURE_DIR"
cat >"$TMP_FIXTURE_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ephemeral fixture"
EOF
chmod +x "$TMP_FIXTURE_FILE"

OUT_DIR_SEEDED="$TMP_DIR/review-seeded"
"$BUILD_SCRIPT" --out-dir "$OUT_DIR_SEEDED" --run-seeded-defects >/dev/null

grep -q 'run_seeded_defects=1' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
grep -q '^## scripts/qa/test-verify-script-basename-overlap.sh$' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
grep -q '^## scripts/qa/test-verify-verify-script-reachability.sh$' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
grep -q '^Actionable broken references:' "$OUT_DIR_SEEDED/10_docs_truth_scan.txt"
grep -q '^## Actionable$' "$OUT_DIR_SEEDED/10_docs_truth_scan.txt"
grep -q '^## Non-actionable (archive/backlog only)$' "$OUT_DIR_SEEDED/10_docs_truth_scan.txt"
if grep -q '^SKIP missing$' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"; then
  echo "FAIL seeded defect run contains missing test references"
  cat "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
  exit 1
fi

echo "PASS test-build-validator-drift-review-packet"
