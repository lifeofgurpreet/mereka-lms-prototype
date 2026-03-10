#!/usr/bin/env bash
# Seeded-defect self-test for verify-evidence-tracking-policy.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-evidence-tracking-policy.sh"

tmpdir="$(mktemp -d -t verify-evidence-policy.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

init_repo() {
  local repo="$1"
  mkdir -p "$repo/docs/evidence/operations"
  git -C "$repo" init -q
  git -C "$repo" config user.email "ci@example.com"
  git -C "$repo" config user.name "CI"
  cat >"$repo/docs/evidence/operations/README.md" <<'EOF'
# Evidence
EOF
  git -C "$repo" add .
  git -C "$repo" commit -q -m "base"
}

run_expect_pass() {
  local repo="$1"
  local label="$2"
  REPO_ROOT_OVERRIDE="$repo" EVIDENCE_POLICY_BASE_REF=HEAD~1 \
    bash "$VERIFY" >/tmp/verify-evidence-policy.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local repo="$1"
  local label="$2"
  set +e
  REPO_ROOT_OVERRIDE="$repo" EVIDENCE_POLICY_BASE_REF=HEAD~1 \
    bash "$VERIFY" >/tmp/verify-evidence-policy.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-evidence-policy.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

# Case 1: markdown evidence additions should pass.
repo_ok="$tmpdir/repo-ok"
init_repo "$repo_ok"
cat >"$repo_ok/docs/evidence/operations/check-1.md" <<'EOF'
# Check 1

Summary evidence with redacted data.
EOF
git -C "$repo_ok" add .
git -C "$repo_ok" commit -q -m "add markdown evidence"
run_expect_pass "$repo_ok" "markdown-only evidence additions pass policy"

# Case 2: binary evidence additions should fail.
repo_bad="$tmpdir/repo-bad"
init_repo "$repo_bad"
printf '\x89PNG\r\n\x1a\n' >"$repo_bad/docs/evidence/operations/screenshot.png"
git -C "$repo_bad" add .
git -C "$repo_bad" commit -q -m "add binary evidence"
run_expect_fail "$repo_bad" "non-markdown evidence artifacts are rejected"

echo "OK"
