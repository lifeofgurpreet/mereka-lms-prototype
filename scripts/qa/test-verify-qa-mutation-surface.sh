#!/usr/bin/env bash
# Seeded-defect self-test for verify-qa-mutation-surface.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-qa-mutation-surface.sh"

tmpdir="$(mktemp -d -t qa-mutation-surface.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

QA_ROOT="$tmpdir/scripts/qa"
ALLOWLIST="$tmpdir/allowlist.json"

mkdir -p "$QA_ROOT"

cat >"$QA_ROOT/fix-one.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

cat >"$QA_ROOT/verify-safe.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" QA_SCAN_ROOT_OVERRIDE="$QA_ROOT" QA_MUTATION_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-qa-mutation-surface.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-qa-mutation-surface.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" QA_SCAN_ROOT_OVERRIDE="$QA_ROOT" QA_MUTATION_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-qa-mutation-surface.out 2>&1
  echo "PASS ${label}"
}

# Case 1: mutating script exists but allowlist empty -> fail.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "mutating_prefixes": ["fix-", "load-"],
  "allowed_scripts": []
}
EOF
run_expect_fail "unallowlisted mutating script is rejected"

# Case 2: allowlist matches -> pass.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "mutating_prefixes": ["fix-", "load-"],
  "allowed_scripts": [
    {
      "path": "scripts/qa/fix-one.sh",
      "owner": "platform-core",
      "rationale": "fixture"
    }
  ]
}
EOF
run_expect_pass "allowlisted mutating script passes"

# Case 3: allowlist stale path -> fail.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "mutating_prefixes": ["fix-", "load-"],
  "allowed_scripts": [
    {
      "path": "scripts/qa/fix-one.sh",
      "owner": "platform-core",
      "rationale": "fixture"
    },
    {
      "path": "scripts/qa/fix-missing.sh",
      "owner": "platform-core",
      "rationale": "fixture"
    }
  ]
}
EOF
run_expect_fail "stale allowlist entry is rejected"

echo "OK"
