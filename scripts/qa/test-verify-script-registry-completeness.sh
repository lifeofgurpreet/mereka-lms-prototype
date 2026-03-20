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
version: "1.2.0"
ci_static_inventory:
  generated_file: .github/ci-scripts-static.txt
  generator: scripts/governance/generate-ci-static-inventory.py
  owner: platform-team
  entries:
    - script: scripts/qa/verify-static-pass.sh
ci_runtime_inventory:
  generated_file: .github/ci-scripts-runtime.txt
  generator: scripts/governance/generate-ci-runtime-inventory.py
  owner: platform-team
  categories:
    - key: LIVE_CLUSTER
      title: Live cluster required
      description: needs kubectl access to a running cluster
  entries:
    - script: scripts/qa/verify-runtime-pass.sh
      category: LIVE_CLUSTER
scripts:
  - path: scripts/release/release-gate.sh
    criticality: release-supporting
  - path: scripts/infra/canonical-release.sh
    criticality: release-supporting
  - path: scripts/qa/verify-static-pass.sh
    criticality: release-blocking
  - path: scripts/qa/verify-runtime-pass.sh
    criticality: release-supporting
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

run_expect_pass "release-blocking scripts require static authority while runtime inventory stays manual"

cat >"$tmpdir/scripts/governance/script-registry.yaml" <<'EOF'
version: "1.2.0"
ci_static_inventory:
  generated_file: .github/ci-scripts-static.txt
  generator: scripts/governance/generate-ci-static-inventory.py
  owner: platform-team
  entries:
    - script: scripts/qa/verify-static-pass.sh
ci_runtime_inventory:
  generated_file: .github/ci-scripts-runtime.txt
  generator: scripts/governance/generate-ci-runtime-inventory.py
  owner: platform-team
  categories:
    - key: LIVE_CLUSTER
      title: Live cluster required
      description: needs kubectl access to a running cluster
  entries:
    - script: scripts/qa/verify-runtime-pass.sh
      category: LIVE_CLUSTER
    - script: scripts/qa/verify-static-pass.sh
      category: LIVE_CLUSTER
scripts:
  - path: scripts/release/release-gate.sh
    criticality: release-supporting
  - path: scripts/infra/canonical-release.sh
    criticality: release-supporting
  - path: scripts/qa/verify-static-pass.sh
    criticality: release-blocking
  - path: scripts/qa/verify-runtime-pass.sh
    criticality: release-supporting
EOF
run_expect_fail "overlap between static and runtime authority is rejected"

cat >"$tmpdir/.github/ci-scripts-runtime.txt" <<'EOF'
# legacy generated file should not matter once authority lives in the registry
EOF
cat >"$tmpdir/scripts/governance/script-registry.yaml" <<'EOF'
version: "1.2.0"
ci_static_inventory:
  generated_file: .github/ci-scripts-static.txt
  generator: scripts/governance/generate-ci-static-inventory.py
  owner: platform-team
  entries:
    - script: scripts/qa/verify-static-pass.sh
ci_runtime_inventory:
  generated_file: .github/ci-scripts-runtime.txt
  generator: scripts/governance/generate-ci-runtime-inventory.py
  owner: platform-team
  categories:
    - key: LIVE_CLUSTER
      title: Live cluster required
      description: needs kubectl access to a running cluster
  entries: []
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
run_expect_fail "runtime inventory cannot satisfy release-blocking coverage"

echo "OK"
