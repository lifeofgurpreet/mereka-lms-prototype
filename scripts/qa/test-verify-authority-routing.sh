#!/usr/bin/env bash
# Seeded-defect self-test for verify-authority-routing.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-authority-routing.sh"

tmpdir="$(mktemp -d -t verify-authority-routing.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/scripts/lib" "$tmpdir/scripts/governance" "$tmpdir/.github/workflows" \
  "$tmpdir/docs/stabilization" "$tmpdir/docs/policies/operations" \
  "$tmpdir/docs/guides/onboarding" "$tmpdir/docs/guides/branding" \
  "$tmpdir/infrastructure/tutor"

write_lms_ops_fixture() {
  cat >"$tmpdir/bin/lms-ops" <<'EOF'
#!/usr/bin/env bash
source scripts/lib/lane-normalize.sh

do_proof() { exec scripts/release/emit-proof-envelope.sh; }
do_inventory() {
  case "${2:-ci-static}" in
    ci-static) exec python3 scripts/governance/generate-ci-static-inventory.py ;;
    ci-runtime) exec python3 scripts/governance/generate-ci-runtime-inventory.py ;;
  esac
}
do_release_gate() { exec scripts/release/release-gate.sh; }
do_smoke() { exec scripts/release/smoke-after-migrate.sh; }
do_preflight() { exec scripts/release/migration-preflight.sh; }
do_topology() { exec scripts/qa/verify-topology-selectors.sh; }

case "${1:-}" in
  migrate) ;;
  inventory) do_inventory ;;
  proof) do_proof ;;
  release-gate) do_release_gate ;;
  smoke) do_smoke ;;
  preflight) do_preflight ;;
  topology) do_topology ;;
esac
EOF
  chmod +x "$tmpdir/bin/lms-ops"
}

write_canonical_entrypoints_fixture() {
  cat >"$tmpdir/scripts/governance/canonical-entrypoints.yaml" <<'EOF'
version: "2.0.0"
front_door:
  canonical: bin/lms-ops
  concerns:
    - inventory
    - migrate
    - proof
    - release-gate
    - smoke
    - preflight
    - topology
EOF
}

write_pass_workflows_fixture() {
  cat >"$tmpdir/.github/workflows/release.yml" <<'EOF'
name: release
jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/infra/release-openedx-gitops.sh --target-env production
EOF
  cat >"$tmpdir/.github/workflows/release-evidence.yml" <<'EOF'
name: release-evidence
jobs:
  evidence:
    runs-on: ubuntu-latest
    steps:
      - run: ./bin/lms-ops proof --concern aggregate --lane staging --skip-cluster
      - run: ./scripts/infra/release-openedx-gitops.sh --target-env staging
EOF
  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster
      - run: ./scripts/infra/release-openedx-gitops.sh --target-env production
EOF
}

write_authority_docs_fixture() {
  cat >"$tmpdir/docs/stabilization/STATIC_VALIDATION_CONTRACT.md" <<'EOF'
# Static Validation Contract

Authority lives in scripts/governance/script-registry.yaml under ci_static_inventory.
Regenerate with python3 scripts/governance/generate-ci-static-inventory.py --write.
Current main uses fetch-depth: 0 on static-validation checkout.
EOF

  cat >"$tmpdir/docs/policies/operations/CI_RUNNER_POLICY.md" <<'EOF'
# CI Runner Policy

The generated derivative is .github/ci-scripts-static.txt.
The authority lives in scripts/governance/script-registry.yaml under ci_static_inventory.
EOF

  cat >"$tmpdir/docs/guides/onboarding/QUICK_START_LOCAL.md" <<'EOF'
# Quick Start

tutor plugins enable mereka_lms
./scripts/infra/tutor-config-save.sh --set LMS_HOST=localhost
EOF

  cat >"$tmpdir/docs/guides/branding/BRANDING.md" <<'EOF'
# Branding

Use ./scripts/infra/tutor-config-save.sh for local Tutor regeneration.
This flows through the internal `apply-patches.sh` call.
EOF

  cat >"$tmpdir/docs/guides/branding/BRANDING_GUARDRAILS.md" <<'EOF'
# Branding Guardrails

For local repair guidance, rerun ./scripts/infra/tutor-config-save.sh.
EOF

  cat >"$tmpdir/infrastructure/tutor/MIGRATION_TO_PLUGIN.md" <<'EOF'
# Migration

## Canonical Local Operator Path

Use ./scripts/infra/tutor-config-save.sh after enabling the Tutor plugin.
apply-patches.sh is now an implementation detail.
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-authority-routing.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-authority-routing.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-authority-routing.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_lms_ops_fixture
write_canonical_entrypoints_fixture
write_pass_workflows_fixture
write_authority_docs_fixture
run_expect_pass "allowlisted transitional callers pass without app-owned bypasses"

cat >"$tmpdir/docs/guides/onboarding/QUICK_START_LOCAL.md" <<'EOF'
# Quick Start

./infrastructure/tutor/apply-patches.sh
EOF
run_expect_fail "quick start must not present apply-patches.sh as the operator command"
write_authority_docs_fixture

cat >"$tmpdir/.github/workflows/drift.yml" <<'EOF'
name: drift
jobs:
  bypass:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/release/release-gate.sh
EOF
run_expect_fail "direct workflow call to app-owned leaf script is rejected"
rm -f "$tmpdir/.github/workflows/drift.yml"

cat >"$tmpdir/.github/workflows/unallowlisted.yml" <<'EOF'
name: unallowlisted
jobs:
  badcaller:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/infra/release-openedx-gitops.sh --target-env production
EOF
run_expect_fail "unallowlisted release-openedx-gitops workflow caller is rejected"
rm -f "$tmpdir/.github/workflows/unallowlisted.yml"

cat >"$tmpdir/docs/stabilization/STATIC_VALIDATION_CONTRACT.md" <<'EOF'
# Static Validation Contract

Authority lives in scripts/governance/script-registry.yaml under ci_static_inventory.
Regenerate with python3 scripts/governance/generate-ci-static-inventory.py --write.
Adding a new verification script: append its path (relative to repo root) to
.github/ci-scripts-static.txt.
EOF
run_expect_fail "manual ci-scripts-static.txt edit guidance is rejected"

write_authority_docs_fixture
cat >"$tmpdir/docs/policies/operations/CI_RUNNER_POLICY.md" <<'EOF'
# CI Runner Policy

The policy is enforced by scripts/qa/verify-ci-runner-policy.sh, which is registered in
.github/ci-scripts-static.txt and runs on every PR.
EOF
run_expect_fail "runner policy must describe generated static inventory authority"

echo "OK"
