#!/usr/bin/env bash
# Seeded-defect self-test for verify-verify-script-reachability.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-verify-script-reachability.sh"

tmpdir="$(mktemp -d -t verify-script-reachability.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/qa/deprecated" "$tmpdir/.github/workflows"

cat >"$tmpdir/scripts/qa/verify-reachable.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$tmpdir/scripts/qa/verify-manual.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$tmpdir/scripts/qa/deprecated/verify-old.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

cat >"$tmpdir/.github/ci-scripts-static.txt" <<'EOF'
scripts/qa/verify-reachable.sh
EOF
cat >"$tmpdir/scripts/qa/run-release-verification-gates.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$tmpdir/scripts/qa/run-operations-gates.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$tmpdir/scripts/qa/run-multisite-governance-gates.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$tmpdir/.github/workflows/ci.yml" <<'EOF'
name: ci
on: [push]
jobs: {}
EOF

ALLOWLIST="$tmpdir/allowlist.json"

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" VERIFY_REACHABILITY_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-verify-script-reachability.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-verify-script-reachability.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" VERIFY_REACHABILITY_ALLOWLIST_OVERRIDE="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-verify-script-reachability.out 2>&1
  echo "PASS ${label}"
}

# Case 1: manual script exists but missing allowlist.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "manual_only_verify_allowlist": []
}
EOF
run_expect_fail "unallowlisted manual-only verify script is rejected"

# Case 2: matching allowlist passes.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "manual_only_verify_allowlist": [
    "scripts/qa/verify-manual.sh"
  ]
}
EOF
run_expect_pass "matching manual-only allowlist passes"

# Case 3: stale allowlist entry fails.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "manual_only_verify_allowlist": [
    "scripts/qa/verify-manual.sh",
    "scripts/qa/verify-reachable.sh"
  ]
}
EOF
run_expect_fail "stale allowlist entry is rejected"

echo "OK"
