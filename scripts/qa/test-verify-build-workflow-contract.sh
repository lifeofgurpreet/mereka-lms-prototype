#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-build-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  push:
    branches: [main]
    paths:
      - 'deploy/k8s/base/apps/openedx/**'
      - 'infrastructure/tutor/**'
      - 'assets/branding/**'
      - 'scripts/infra/**'
      - 'scripts/lib/**'
      - 'scripts/qa/verify-build-provenance.sh'
      - 'scripts/qa/verify-release-bundle.sh'
      - '.github/workflows/build-tutor-images.yml'
  workflow_dispatch:
    inputs:
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  build-openedx:
    steps:
      - name: Verify OpenEdX build cache health
        run: |
          SUMMARY="${SUMMARY}\n✅ GHA cache exporters intentionally absent for OpenEdX build (docker driver + local image export)"
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
      - name: Verify OpenEdX image branding contract
        run: echo ok
  build-mfe:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${MFE_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
  release-bundle:
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' }}
    steps:
      - run: |
          source ./scripts/lib/lane-normalize.sh
          TARGET_ENV_RAW="${{ inputs.target_environment }}"
          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"
          test -n "$TARGET_ENV"
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: |
            var/ci/build-provenance.json
            var/ci/release-gate-envelope.json
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-build-workflow-contract.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-build-workflow-contract.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-build-workflow-contract.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "build workflow contract passes with lms-ops proof + envelope upload"

cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  workflow_dispatch:
    inputs:
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  build-openedx:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
  build-mfe:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${MFE_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
  release-bundle:
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' }}
    steps:
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: |
            var/ci/build-provenance.json
            var/ci/release-gate-envelope.json
EOF
run_expect_fail "missing canonical target_environment normalization is rejected"

# Force release-bundle to hard-fail on placeholder env => must fail
cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  push:
    branches: [main]
    paths:
      - 'deploy/k8s/base/apps/openedx/**'
      - 'infrastructure/tutor/**'
      - 'assets/branding/**'
      - 'scripts/infra/**'
      - 'scripts/lib/**'
      - 'scripts/qa/verify-build-provenance.sh'
      - 'scripts/qa/verify-release-bundle.sh'
      - '.github/workflows/build-tutor-images.yml'
  workflow_dispatch:
    inputs:
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  build-openedx:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
  build-mfe:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${MFE_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
  release-bundle:
    steps:
      - run: |
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            TARGET_ENV="${{ inputs.target_environment }}"
            if [[ "$TARGET_ENV" == "select-environment" ]]; then
              echo "target_environment must be explicitly selected before generating a release bundle." >&2
              exit 1
            fi
          fi
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' }}
    steps:
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: |
          source ./scripts/lib/lane-normalize.sh
          TARGET_ENV_RAW="${{ inputs.target_environment }}"
          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"
          test -n "$TARGET_ENV"
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: var/ci/build-provenance.json
EOF
run_expect_fail "release bundle must skip placeholder manual environment instead of failing inside the job"

# Reintroduce push-to-main auto-deploy => must fail
cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  workflow_dispatch:
    inputs:
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  build-openedx:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
  build-mfe:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${MFE_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
  release-bundle:
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && ((github.event_name == 'push' && github.ref == 'refs/heads/main') || (github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment')) }}
    steps:
      - run: |
          source ./scripts/lib/lane-normalize.sh
          TARGET_ENV_RAW="${{ inputs.target_environment }}"
          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"
          test -n "$TARGET_ENV"
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: |
            var/ci/build-provenance.json
            var/ci/release-gate-envelope.json
EOF
run_expect_fail "update-gitops must not auto-run on push to main"

# Reintroduce stale OpenEdX cache-health messaging => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Verify OpenEdX build cache health\n'
    '        run: |\n'
    '          SUMMARY="${SUMMARY}\\n✅ GHA cache exporters intentionally absent for OpenEdX build (docker driver + local image export)"\n',
    '      - name: Verify OpenEdX build cache health\n'
    '        run: |\n'
    '          SUMMARY="${SUMMARY}\\n❌ GHA cache read/write flags NOT found in build command"\n',
)
p.write_text(text)
PY
run_expect_fail "stale OpenEdX cache-health messaging is rejected"

# Reintroduce stale mutable-tag auto-deploy wording => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace('      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"\n',
                    '      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"\n'
                    '      - run: echo "Mutable tag means dev auto-deploys via ArgoCD"\n')
p.write_text(text)
PY
run_expect_fail "stale mutable-tag auto-deploy wording is rejected"

# Remove lms-ops call => must fail
cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  workflow_dispatch:
    inputs:
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  build-openedx:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
  build-mfe:
    steps:
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${MFE_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
  release-bundle:
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' }}
    steps:
      - run: |
          source ./scripts/lib/lane-normalize.sh
          TARGET_ENV_RAW="${{ inputs.target_environment }}"
          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"
          test -n "$TARGET_ENV"
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: var/ci/build-provenance.json
EOF
run_expect_fail "missing lms-ops proof emission is rejected"

# Remove script trigger coverage => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace("      - 'scripts/infra/**'\n", "")
p.write_text(text)
PY
run_expect_fail "missing script trigger path coverage is rejected"

# Remove SBOM timeout guard => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n',
    '      - run: "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n',
)
p.write_text(text)
PY
run_expect_fail "OpenEdX SBOM generation must stay timeout-guarded"

echo "OK"
