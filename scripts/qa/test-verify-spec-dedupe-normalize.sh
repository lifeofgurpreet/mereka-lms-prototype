#!/usr/bin/env bash
# Seeded-defect self-test for verify-spec-dedupe-normalize.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-spec-dedupe-normalize.sh"

tmpdir="$(mktemp -d -t verify-spec-dedupe.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/specs/testmaps" "$tmpdir/scripts/qa/spec-tools"

cat >"$tmpdir/scripts/qa/spec-tools/mereka_spec_lint.py" <<'EOF'
#!/usr/bin/env python3
print("PASS lint")
EOF
chmod +x "$tmpdir/scripts/qa/spec-tools/mereka_spec_lint.py"

cat >"$tmpdir/scripts/qa/spec-tools/spec_coverage_dashboard.py" <<'EOF'
#!/usr/bin/env python3
print("GREEN 100%")
EOF
chmod +x "$tmpdir/scripts/qa/spec-tools/spec_coverage_dashboard.py"

cat >"$tmpdir/specs/testmaps/example_spec.testmap.yml" <<'EOF'
spec: specs/example_spec.md
acceptance_criteria:
  - id: AC-EXAMPLE-001
    checks:
      - type: automated
        file: tests/test_example.py
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-spec-dedupe.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-spec-dedupe.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-spec-dedupe.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/specs/example_spec.md" <<'EOF'
# Example Spec

## Acceptance Criteria
- [ ] AC-EXAMPLE-001 MUST be unique
- [ ] AC-EXAMPLE-002 MUST be covered
EOF
run_expect_pass "normalized specs with unique AC IDs pass"

cat >"$tmpdir/specs/example_spec.md" <<'EOF'
# Example Spec

## Acceptance Criteria
- [ ] AC-EXAMPLE-001 MUST be unique
- [ ] AC-EXAMPLE-001 MUST not be duplicated
EOF
run_expect_fail "duplicate checkbox AC IDs are rejected"

cat >"$tmpdir/specs/example_spec.md" <<'EOF'
# Example Spec

## Acceptance Criteria
Requirements are documented here without checkbox AC IDs.
EOF
run_expect_fail "acceptance sections without checkbox AC IDs are rejected"

echo "OK"
