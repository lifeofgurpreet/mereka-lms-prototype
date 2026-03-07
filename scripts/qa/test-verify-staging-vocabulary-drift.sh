#!/usr/bin/env bash
# Seeded-defect self-test for verify-staging-vocabulary-drift.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-staging-vocabulary-drift.sh"

tmpdir="$(mktemp -d -t staging-vocab-drift.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/qa"
cat >"$tmpdir/scripts/qa/verify-a.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "staging"
EOF
cat >"$tmpdir/scripts/qa/verify-b.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "prod"
EOF

ALLOWLIST="$tmpdir/allowlist.json"

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" STAGING_VOCAB_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-staging-vocabulary-drift.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-staging-vocabulary-drift.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" STAGING_VOCAB_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-staging-vocabulary-drift.out 2>&1
  echo "PASS ${label}"
}

# Case 1: staging file missing from allowlist.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "staging_reference_allowlist": []
}
EOF
run_expect_fail "missing allowlist entry is rejected"

# Case 2: matching allowlist passes.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "staging_reference_allowlist": [
    "scripts/qa/verify-a.sh"
  ]
}
EOF
run_expect_pass "matching allowlist passes"

# Case 3: stale allowlist entry fails.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "staging_reference_allowlist": [
    "scripts/qa/verify-a.sh",
    "scripts/qa/verify-b.sh"
  ]
}
EOF
run_expect_fail "stale allowlist entry is rejected"

echo "OK"
