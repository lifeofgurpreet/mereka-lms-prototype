#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-gitops-guardrails.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-release-gitops-guardrails.sh"

tmpdir="$(mktemp -d -t verify-release-gitops-guardrails.XXXXXX)"
stdout_file="$(mktemp "${TMPDIR:-/tmp}/verify-release-gitops-guardrails.out.XXXXXX")"
trap 'rm -rf "$tmpdir"; rm -f "$stdout_file"' EXIT

mkdir -p "$tmpdir/scripts/infra"

write_pass_fixture() {
  cat >"$tmpdir/scripts/infra/release-openedx-gitops.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIRM_RELEASE_OPENEDX_GITOPS="${CONFIRM_RELEASE_OPENEDX_GITOPS:-}"
CONFIRM_APPLY_TOKEN="RELEASE_OPENEDX_GITOPS"
CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS="${CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS:-}"
CONFIRM_PUSH_TOKEN="PUSH_RELEASE_OPENEDX_GITOPS"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
echo "Refusing --apply without explicit confirmation token"
echo "Refusing --push without explicit confirmation token"
echo "Refusing production --apply without ALLOW_PROD_APPLY=1"
echo "Push rejected for $repo; rebasing onto origin/main before retry."
git rebase --autostash origin/main
EOF
  chmod +x "$tmpdir/scripts/infra/release-openedx-gitops.sh"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >"$stdout_file" 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >"$stdout_file" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat "$stdout_file" >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "all guardrail token patterns present pass checks"

cat >"$tmpdir/scripts/infra/release-openedx-gitops.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIRM_RELEASE_OPENEDX_GITOPS="${CONFIRM_RELEASE_OPENEDX_GITOPS:-}"
CONFIRM_APPLY_TOKEN="RELEASE_OPENEDX_GITOPS"
CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS="${CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS:-}"
CONFIRM_PUSH_TOKEN="PUSH_RELEASE_OPENEDX_GITOPS"
echo "Refusing --apply without explicit confirmation token"
echo "Refusing --push without explicit confirmation token"
EOF
run_expect_fail "missing ALLOW_PROD_APPLY and push retry guardrails are rejected"

echo "OK"
