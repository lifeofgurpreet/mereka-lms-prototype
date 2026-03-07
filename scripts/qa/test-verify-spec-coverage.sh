#!/usr/bin/env bash
# Seeded-defect self-test for verify-spec-coverage.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-spec-coverage.sh"

tmpdir="$(mktemp -d -t verify-spec-coverage.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/specs/testmaps" "$tmpdir/tests"

cat >"$tmpdir/specs/sample_spec.md" <<'EOF'
# Sample Spec

## Acceptance Criteria
- [ ] AC-SAMPLE-001 MUST have seeded coverage
- [ ] AC-SAMPLE-002 MUST have seeded coverage
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT="$tmpdir" SPEC_COVERAGE_FLOOR=100 bash "$VERIFY" >/tmp/verify-spec-coverage.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT="$tmpdir" SPEC_COVERAGE_FLOOR=60 bash "$VERIFY" >/tmp/verify-spec-coverage.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-spec-coverage.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/specs/testmaps/sample_spec.testmap.yml" <<'EOF'
spec: specs/sample_spec.md
acceptance_criteria:
  - id: AC-SAMPLE-001
    checks:
      - type: automated
        file: tests/test_sample.py
  - id: AC-SAMPLE-002
    checks:
      - type: manual
        file: tests/test_sample_manual.py
EOF
run_expect_pass "coverage passes when all AC blocks are wired"

cat >"$tmpdir/specs/testmaps/sample_spec.testmap.yml" <<'EOF'
spec: specs/sample_spec.md
acceptance_criteria:
  - id: AC-SAMPLE-001
    checks:
      - type: automated
        file: tests/test_sample.py
  - id: AC-SAMPLE-002
    checks:
      - type: manual
        notes: "no automated coverage wired yet"
EOF
run_expect_fail "coverage floor fails when AC wiring is incomplete"

echo "OK"
