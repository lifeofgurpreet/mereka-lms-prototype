#!/usr/bin/env bash
# Seeded-defect self-test for verify-qa-readonly-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-qa-readonly-contract.sh"

tmpdir="$(mktemp -d -t verify-qa-readonly.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/qa/fixtures"

cat >"$tmpdir/scripts/qa/verify-safe.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "safe"
EOF

cat >"$tmpdir/scripts/qa/verify-mutating.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
kubectl apply -f deploy/k8s/base
EOF

cat >"$tmpdir/scripts/qa/fix-runtime.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "fix"
EOF

chmod +x "$tmpdir/scripts/qa/"*.sh

ALLOWLIST="$tmpdir/scripts/qa/fixtures/qa-mutating-scripts-allowlist.json"

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" QA_READONLY_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-qa-readonly.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-qa-readonly.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" QA_READONLY_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-qa-readonly.out 2>&1
  echo "PASS ${label}"
}

# Case 1: missing allowlist for mutating scripts should fail.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "allowed_scripts": []
}
EOF
run_expect_fail "unallowlisted mutating qa scripts are rejected"

# Case 2: correct allowlist should pass.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "allowed_scripts": [
    {
      "path": "scripts/qa/fix-runtime.sh",
      "reason": "intentional mutating prefix"
    },
    {
      "path": "scripts/qa/verify-mutating.sh",
      "reason": "intentional kubectl mutation"
    }
  ]
}
EOF
run_expect_pass "matching mutating allowlist passes"

# Case 3: stale allowlist entries should fail.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "allowed_scripts": [
    {
      "path": "scripts/qa/fix-runtime.sh",
      "reason": "intentional mutating prefix"
    },
    {
      "path": "scripts/qa/verify-mutating.sh",
      "reason": "intentional kubectl mutation"
    },
    {
      "path": "scripts/qa/verify-safe.sh",
      "reason": "stale entry"
    }
  ]
}
EOF
run_expect_fail "stale mutating allowlist entry is rejected"

echo "OK"
