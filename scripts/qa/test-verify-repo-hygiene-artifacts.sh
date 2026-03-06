#!/usr/bin/env bash
# Seeded-defect self-test for verify-repo-hygiene-artifacts.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-repo-hygiene-artifacts.sh"

tmpdir="$(mktemp -d -t repo-hygiene-artifacts.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

git init -q "$tmpdir"

mkdir -p "$tmpdir/scripts/migrations/kajabi/output"
mkdir -p "$tmpdir/migrations/mct/logs"
mkdir -p "$tmpdir/src"

cat >"$tmpdir/src/main.sh" <<'EOF'
#!/usr/bin/env bash
echo ok
EOF
cat >"$tmpdir/scripts/migrations/kajabi/output/users.csv" <<'EOF'
email
user@example.com
EOF
cat >"$tmpdir/migrations/mct/logs/run.log" <<'EOF'
log
EOF

(
  cd "$tmpdir"
  git add src/main.sh scripts/migrations/kajabi/output/users.csv migrations/mct/logs/run.log
)

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-repo-hygiene-artifacts.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-repo-hygiene-artifacts.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-repo-hygiene-artifacts.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail "tracked migration output/log artifacts are rejected"

(
  cd "$tmpdir"
  git rm --cached -q scripts/migrations/kajabi/output/users.csv migrations/mct/logs/run.log
)
run_expect_pass "clean tracked tree passes"

echo "OK"
