#!/usr/bin/env bash
# Lightweight self-test for build-validator-drift-review-packet.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/qa/build-validator-drift-review-packet.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
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

OUT_DIR_SEEDED="$TMP_DIR/review-seeded"
"$BUILD_SCRIPT" --out-dir "$OUT_DIR_SEEDED" --run-seeded-defects >/dev/null

grep -q 'run_seeded_defects=1' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
grep -q '^## scripts/qa/test-verify-qa-readonly-contract.sh$' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"

echo "PASS test-build-validator-drift-review-packet"
