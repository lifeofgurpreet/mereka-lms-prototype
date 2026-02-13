#!/usr/bin/env bash
set -euo pipefail

# Release Evidence Pack Generator
# Bundles verification artifacts for release sign-off
#
# Usage: ./scripts/qa/generate-evidence-pack.sh [--output-dir DIR]
# Default output: docs/verification/evidence-packs/YYYY-MM-DD/

OUTPUT_DIR="${1:-docs/verification/evidence-packs/$(date +%Y-%m-%d)}"
mkdir -p "$OUTPUT_DIR"

echo "=== Generating Release Evidence Pack ==="
echo "Output: $OUTPUT_DIR"

# 1. Git state
echo "--- Git State ---"
git log --oneline -20 > "$OUTPUT_DIR/git-log.txt"
git diff --stat HEAD~5..HEAD > "$OUTPUT_DIR/git-diff-stat.txt" 2>/dev/null || echo "Not enough commits" > "$OUTPUT_DIR/git-diff-stat.txt"

# 2. Spec index
echo "--- Spec Index ---"
cp specs/INDEX.md "$OUTPUT_DIR/spec-index.md" 2>/dev/null || echo "No INDEX.md" > "$OUTPUT_DIR/spec-index.md"

# 3. Beads summary
echo "--- Beads Summary ---"
br list > "$OUTPUT_DIR/beads-open.txt" 2>/dev/null || echo "br not available" > "$OUTPUT_DIR/beads-open.txt"

# 4. Verification results (if gate timings exist)
echo "--- Verification Timing ---"
if [ -f "docs/verification/gate_timings.jsonl" ]; then
  tail -20 docs/verification/gate_timings.jsonl > "$OUTPUT_DIR/recent-gate-timings.jsonl"
else
  echo "No gate timings recorded yet" > "$OUTPUT_DIR/recent-gate-timings.jsonl"
fi

# 5. Flake quarantine state
echo "--- Flake Quarantine ---"
cp docs/verification/FLAKE_QUARANTINE.yml "$OUTPUT_DIR/flake-quarantine.yml" 2>/dev/null || echo "No quarantine file" > "$OUTPUT_DIR/flake-quarantine.yml"

# 6. Certification scorecard
echo "--- Certification Scorecard ---"
cp docs/verification/CERTIFICATION_SCORECARD.yml "$OUTPUT_DIR/certification-scorecard.yml" 2>/dev/null || echo "No scorecard" > "$OUTPUT_DIR/certification-scorecard.yml"

# 7. Assurance case
echo "--- Assurance Case ---"
cp docs/verification/ASSURANCE_CASE.md "$OUTPUT_DIR/assurance-case.md" 2>/dev/null || echo "No assurance case" > "$OUTPUT_DIR/assurance-case.md"

# 8. Summary manifest
cat > "$OUTPUT_DIR/MANIFEST.md" << MANIFEST_EOF
# Release Evidence Pack
- **Generated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- **Branch**: $(git branch --show-current 2>/dev/null || echo "detached")
- **HEAD**: $(git rev-parse --short HEAD)
- **Generator**: scripts/qa/generate-evidence-pack.sh

## Contents
| File | Description |
|------|-------------|
| git-log.txt | Last 20 commits |
| git-diff-stat.txt | Change summary from last 5 commits |
| spec-index.md | Current spec index (34 specs, 883 ACs) |
| beads-open.txt | Open beads at pack time |
| recent-gate-timings.jsonl | Last 20 gate timing records |
| flake-quarantine.yml | Current quarantine state |
| certification-scorecard.yml | Release gate status |
| assurance-case.md | Claim-argument-evidence ledger |
MANIFEST_EOF

echo ""
echo "=== Evidence Pack Complete ==="
echo "Files: $(ls -1 "$OUTPUT_DIR" | wc -l)"
echo "Location: $OUTPUT_DIR"
