#!/usr/bin/env bash
# Seeded-defect self-test for verify-documentation-standards.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-documentation-standards.sh"

tmpdir="$(mktemp -d -t verify-doc-standards.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/docs/guides/standards" \
  "$tmpdir/docs/ops/runbooks" \
  "$tmpdir/docs/adr" \
  "$tmpdir/specs" \
  "$tmpdir/scripts/qa"

cat >"$tmpdir/docs/guides/standards/DOCUMENTATION_STANDARDS.md" <<'EOF'
# Documentation Standards
EOF

cat >"$tmpdir/docs/ops/runbooks/example.md" <<'EOF'
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-01_

# Example Runbook
EOF

cat >"$tmpdir/docs/adr/001-example.md" <<'EOF'
# ADR 001

## Context
Context text.

## Decision
Decision text.

## Consequences
Consequences text.
EOF

cat >"$tmpdir/specs/example_spec.md" <<'EOF'
---
title: Example Spec
---

# Example Spec
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-doc-standards.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-doc-standards.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-doc-standards.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass "documentation standards pass for compliant fixture set"

cat >"$tmpdir/specs/example_spec.md" <<'EOF'
# Example Spec

No YAML frontmatter here.
EOF
run_expect_fail "specs missing YAML frontmatter are rejected"

echo "OK"
