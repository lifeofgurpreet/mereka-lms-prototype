#!/usr/bin/env bash
# Seeded-defect self-test for verify-script-registry-completeness.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="${ROOT_DIR}/scripts/qa/verify-script-registry-completeness.sh"

tmpdir="$(mktemp -d -t verify-script-registry-completeness.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/.github" \
  "$tmpdir/scripts/governance" \
  "$tmpdir/scripts/infra" \
  "$tmpdir/scripts/qa" \
  "$tmpdir/scripts/release"

write_script() {
  local path="$1"
  cat >"$tmpdir/$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
  chmod +x "$tmpdir/$path"
}

write_registry() {
  cat >"$tmpdir/scripts/governance/script-registry.yaml" <<'EOF'
version: "1.1.1"
ci_static_inventory:
  generated_file: .github/ci-scripts-static.txt
  generator: scripts/governance/generate-ci-static-inventory.py
  owner: platform-team
  entries:
    - script: scripts/qa/verify-static-pass.sh
scripts:
  - path: scripts/release/release-gate.sh
    criticality: release-supporting
  - path: scripts/infra/canonical-release.sh
    criticality: release-supporting
  - path: scripts/qa/verify-static-pass.sh
    criticality: release-blocking
  - path: scripts/qa/verify-runtime-pass.sh
    criticality: release-blocking
EOF
}

write_runtime_inventory() {
  cat >"$tmpdir/.github/ci-scripts-runtime.txt" <<'EOF'
# TEMP_BRIDGE runtime inventory fixture
scripts/qa/verify-runtime-pass.sh  # LIVE_CLUSTER
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-script-registry-completeness.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-script-registry-completeness.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-script-registry-completeness.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_script "scripts/release/release-gate.sh"
write_script "scripts/infra/canonical-release.sh"
write_script "scripts/qa/verify-static-pass.sh"
write_script "scripts/qa/verify-runtime-pass.sh"
write_registry
write_runtime_inventory

run_expect_pass "release-blocking scripts can be satisfied by static authority or runtime bridge"

cat >"$tmpdir/.github/ci-scripts-runtime.txt" <<'EOF'
# TEMP_BRIDGE runtime inventory fixture
scripts/qa/verify-runtime-pass.sh  # LIVE_CLUSTER
scripts/qa/verify-static-pass.sh   # DUPLICATE
EOF
run_expect_fail "overlap between static authority and runtime bridge is rejected"

write_runtime_inventory
cat >"$tmpdir/.github/ci-scripts-runtime.txt" <<'EOF'
# TEMP_BRIDGE runtime inventory fixture
# verify-runtime-pass intentionally removed
EOF
run_expect_fail "missing release-blocking runtime coverage is rejected"

echo "OK"
