#!/usr/bin/env bash
# Seeded-defect self-test for verify-authn-submodule-path-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-authn-submodule-path-contract.sh"

tmpdir="$(mktemp -d -t verify-authn-submodule.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/docs/guides/onboarding" "$tmpdir/specs"

git -C "$tmpdir" init -q

cat >"$tmpdir/.gitmodules" <<'EOF'
[submodule "tmp/frontend-app-authn"]
	path = tmp/frontend-app-authn
	url = https://github.com/openedx/frontend-app-authn
EOF

cat >"$tmpdir/.gitignore" <<'EOF'
tmp/frontend-app-*/
!tmp/frontend-app-authn/
EOF

cat >"$tmpdir/README.md" <<'EOF'
Canonical path: tmp/frontend-app-authn
EOF
cat >"$tmpdir/docs/guides/onboarding/REPOSITORY_GUIDE.md" <<'EOF'
Use tmp/frontend-app-authn for authn submodule.
EOF
cat >"$tmpdir/specs/repository-structure_spec.md" <<'EOF'
Contract path: tmp/frontend-app-authn
EOF

# Track canonical submodule as gitlink (without requiring network clone).
git -C "$tmpdir" update-index --add --cacheinfo 160000 e9b0902f497bc7cb9b2b44c36a668062c87e872a tmp/frontend-app-authn

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-authn-submodule.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-authn-submodule.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-authn-submodule.out 2>&1
  echo "PASS ${label}"
}

# Case 1: happy path passes.
run_expect_pass "canonical path/url/gitlink contract passes"

# Case 2: URL drift fails.
cat >"$tmpdir/.gitmodules" <<'EOF'
[submodule "tmp/frontend-app-authn"]
	path = tmp/frontend-app-authn
	url = https://github.com/example/wrong-authn
EOF
run_expect_fail "canonical URL drift is rejected"

# Restore canonical URL for next case.
cat >"$tmpdir/.gitmodules" <<'EOF'
[submodule "tmp/frontend-app-authn"]
	path = tmp/frontend-app-authn
	url = https://github.com/openedx/frontend-app-authn
EOF

# Case 3: rogue additional tmp/frontend-app-* tracking fails.
git -C "$tmpdir" update-index --add --cacheinfo 160000 e9b0902f497bc7cb9b2b44c36a668062c87e872a tmp/frontend-app-learning
run_expect_fail "rogue tmp/frontend-app-* tracking is rejected"

echo "OK"
