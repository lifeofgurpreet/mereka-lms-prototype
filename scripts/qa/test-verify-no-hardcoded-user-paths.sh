#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-no-hardcoded-user-paths.sh"

fail() {
  echo "FAIL $1" >&2
  exit 1
}

pass() {
  echo "PASS $1"
}

make_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  git -C "$repo" init -q
}

tmp_bad="$(mktemp -d)"
tmp_good="$(mktemp -d)"
tmp_allowlist="$(mktemp)"
trap 'rm -rf "$tmp_bad" "$tmp_good"; rm -f "$tmp_allowlist"' EXIT

make_repo "$tmp_bad"
cat > "$tmp_bad/scripts/bad.sh" <<'EOF'
#!/usr/bin/env bash
BASE_DIR="/home/gurpreet/projects/k8s/mereka-lms/var/migrations/mct/course_packages_category"
EOF
git -C "$tmp_bad" add scripts/bad.sh

if REPO_ROOT_OVERRIDE="$tmp_bad" ALLOWLIST_FILE_OVERRIDE="$tmp_allowlist" "$VERIFY_SCRIPT" >/dev/null 2>&1; then
  fail "hardcoded user path should be rejected"
else
  pass "hardcoded user path is rejected"
fi

make_repo "$tmp_good"
cat > "$tmp_good/scripts/good.sh" <<'EOF'
#!/usr/bin/env bash
BASE_DIR="${REPO_ROOT}/var/migrations/mct/course_packages_category"
EOF
git -C "$tmp_good" add scripts/good.sh

if REPO_ROOT_OVERRIDE="$tmp_good" ALLOWLIST_FILE_OVERRIDE="$tmp_allowlist" "$VERIFY_SCRIPT" >/dev/null 2>&1; then
  pass "clean script surface passes"
else
  fail "clean script surface should pass"
fi

echo "OK"
