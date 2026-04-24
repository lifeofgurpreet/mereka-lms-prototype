#!/usr/bin/env bash
# Seeded-defect self-test for verify-script-basename-overlap.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-script-basename-overlap.sh"

tmpdir="$(mktemp -d -t script-basename-overlap.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

SCAN_ROOT="$tmpdir/scripts"
ALLOWLIST="$tmpdir/allowlist.json"

mkdir -p "$SCAN_ROOT/infra" "$SCAN_ROOT/qa"
cat >"$SCAN_ROOT/infra/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
cat >"$SCAN_ROOT/qa/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" SCRIPT_BASENAME_SCAN_ROOT="$SCAN_ROOT" SCRIPT_BASENAME_ALLOWLIST="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-script-basename-overlap.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-script-basename-overlap.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" SCRIPT_BASENAME_SCAN_ROOT="$SCAN_ROOT" SCRIPT_BASENAME_ALLOWLIST="$ALLOWLIST" \
    bash "$VERIFY" >/tmp/verify-script-basename-overlap.out 2>&1
  echo "PASS ${label}"
}

# Case 1: duplicate exists with no contract.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "overlaps": []
}
EOF
run_expect_fail "missing contract is rejected"

# Case 2: valid wrapper contract passes.
cat >"$ALLOWLIST" <<'EOF'
{
  "version": 1,
  "overlaps": [
    {
      "basename": "check.sh",
      "contract_type": "wrapper",
      "canonical": "scripts/infra/check.sh",
      "wrappers": ["scripts/qa/check.sh"],
      "paths": ["scripts/infra/check.sh", "scripts/qa/check.sh"]
    }
  ]
}
EOF
run_expect_pass "matching wrapper contract passes"

# Case 3: cluster drift vs allowlist is rejected.
mkdir -p "$SCAN_ROOT/ops"
cat >"$SCAN_ROOT/ops/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
run_expect_fail "path drift is rejected"

echo "OK"
