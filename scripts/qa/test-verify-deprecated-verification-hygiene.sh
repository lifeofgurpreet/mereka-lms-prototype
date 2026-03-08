#!/usr/bin/env bash
# Seeded-defect self-test for verify-deprecated-verification-hygiene.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-deprecated-verification-hygiene.sh"

tmpdir="$(mktemp -d -t verify-deprecated-hygiene.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/docs/operations/verification" \
  "$tmpdir/.github/workflows" \
  "$tmpdir/scripts/qa/deprecated"

SCRIPT_PATH="scripts/qa/deprecated/verify-legacy-smoke.sh"
cat >"$tmpdir/$SCRIPT_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "legacy"
EOF
chmod +x "$tmpdir/$SCRIPT_PATH"

cat >"$tmpdir/verification/manifests/deprecated_verify_scripts.json" <<EOF
{
  "scripts": [
    {
      "path": "$SCRIPT_PATH",
      "replacement_entrypoint": "scripts/qa/run-spec-integrity-gates.sh",
      "reason": "covered by canonical gate"
    }
  ]
}
EOF

cat >"$tmpdir/.github/workflows/ci.yml" <<'EOF'
name: ci
on: [push]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/qa/run-spec-integrity-gates.sh
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-deprecated-hygiene.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-deprecated-hygiene.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-deprecated-hygiene.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/.github/ci-scripts-static.txt" <<'EOF'
scripts/qa/verify-repo-structure.sh
scripts/qa/run-spec-integrity-gates.sh
EOF
run_expect_pass "deprecated entries pass when removed from CI/workflow references"

cat >"$tmpdir/.github/ci-scripts-static.txt" <<EOF
scripts/qa/verify-repo-structure.sh
$SCRIPT_PATH
EOF
run_expect_fail "deprecated scripts listed in static CI are rejected"

cat >"$tmpdir/.github/ci-scripts-static.txt" <<'EOF'
scripts/qa/verify-repo-structure.sh
scripts/qa/run-spec-integrity-gates.sh
EOF
cat >"$tmpdir/.github/workflows/ci.yml" <<EOF
name: ci
on: [push]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: ./$SCRIPT_PATH
EOF
run_expect_fail "deprecated scripts referenced directly in workflows are rejected"

echo "OK"
