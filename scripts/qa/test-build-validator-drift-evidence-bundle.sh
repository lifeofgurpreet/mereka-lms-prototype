#!/usr/bin/env bash
# Lightweight self-test for build-validator-drift-evidence-bundle.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/qa/build-validator-drift-evidence-bundle.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OUT_DIR="$TMP_DIR/bundle"
"$BUILD_SCRIPT" --out-dir "$OUT_DIR" >/dev/null

required_files=(
  "$OUT_DIR/index.md"
  "$OUT_DIR/01_scope.md"
  "$OUT_DIR/02_claims.json"
  "$OUT_DIR/03_catalog.csv"
  "$OUT_DIR/04_duplicate_clusters.txt"
  "$OUT_DIR/05_ci_reachability.json"
  "$OUT_DIR/06_mutability_scan.txt"
  "$OUT_DIR/07_env_taxonomy.txt"
  "$OUT_DIR/08_generated_artifact_leakage.txt"
  "$OUT_DIR/09_seeded_defect_results.txt"
  "$OUT_DIR/10_docs_truth_scan.txt"
  "$OUT_DIR/11_open_risks.md"
  "$OUT_DIR/12_limits.md"
  "$OUT_DIR/command-status.tsv"
)

for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || { echo "FAIL missing: $f" >&2; exit 1; }
done

grep -q "## 1. Scope" "$OUT_DIR/index.md"
grep -q "## 12. Limits" "$OUT_DIR/index.md"
grep -q '"canonical_hypothesis"' "$OUT_DIR/02_claims.json"
python3 - "$OUT_DIR/05_ci_reachability.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

scripts = payload.get("scripts", [])
if not scripts:
    raise SystemExit("expected at least one script entry in 05_ci_reachability.json")
if "reachable_via_script_chain" not in scripts[0]:
    raise SystemExit("missing reachable_via_script_chain in reachability rows")
if "manual_runbook_refs" not in scripts[0]:
    raise SystemExit("missing manual_runbook_refs in reachability output")
PY
head -n1 "$OUT_DIR/command-status.tsv" | grep -q "name"
head -n1 "$OUT_DIR/command-status.tsv" | grep -q "exit_code"
head -n1 "$OUT_DIR/command-status.tsv" | grep -q "output_path"
if grep -q 'scripts/qa/deprecated/' "$OUT_DIR/11_open_risks.md"; then
  echo "FAIL deprecated validators should not appear as open unreachable risks"
  cat "$OUT_DIR/11_open_risks.md"
  exit 1
fi

OUT_DIR_SEEDED="$TMP_DIR/bundle-seeded"
"$BUILD_SCRIPT" --out-dir "$OUT_DIR_SEEDED" --run-seeded-defects >/dev/null
if grep -q '^SKIP .* (missing)$' "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"; then
  echo "FAIL seeded defect run contains missing test references"
  cat "$OUT_DIR_SEEDED/09_seeded_defect_results.txt"
  exit 1
fi

echo "PASS test-build-validator-drift-evidence-bundle"
