#!/usr/bin/env bash
# Seeded-defect self-test for verify-branding-script-portability.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-branding-script-portability.sh"

tmpdir="$(mktemp -d -t verify-branding-portability.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/branding"

cat >"$tmpdir/scripts/branding/portable.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
echo "$REPO_ROOT"
EOF

chmod +x "$tmpdir/scripts/branding/portable.sh"

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-branding-portability.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-branding-portability.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-branding-portability.out 2>&1
  echo "PASS ${label}"
}

# Case 1: portable scripts pass.
run_expect_pass "portable branding scripts pass portability contract"

# Case 2: workstation path literal fails.
cat >"$tmpdir/scripts/branding/nonportable.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SOURCE_PATH="/home/alice/projects/brand-assets"
echo "$SOURCE_PATH"
EOF
chmod +x "$tmpdir/scripts/branding/nonportable.sh"
run_expect_fail "workstation absolute path literals are rejected"

echo "OK"
