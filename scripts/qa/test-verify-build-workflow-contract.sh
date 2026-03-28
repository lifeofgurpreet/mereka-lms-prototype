#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-build-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/infra"
cat >"$tmpdir/scripts/infra/resolve-build-scope.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'build_openedx=true\nbuild_mfe=true\nscope_label=both\n' >> "$1"
EOF
chmod +x "$tmpdir/scripts/infra/resolve-build-scope.sh"

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
      - 'infrastructure/tutor/apply-patches.sh'
      - 'infrastructure/tutor/patches/**'
      - 'scripts/infra/**'
      - 'scripts/lib/**'
      - 'scripts/qa/verify-build-provenance.sh'
      - 'scripts/qa/verify-release-bundle.sh'
      - '.github/workflows/build-tutor-images.yml'
  workflow_dispatch:
    inputs:
      build_openedx:
        type: boolean
        default: true
      build_mfe:
        type: boolean
        default: true
      update_gitops:
        type: boolean
        default: false
      target_environment:
        type: choice
        options: [select-environment, production, staging]
permissions:
  contents: write
jobs:
  resolve-build-scope:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: ./scripts/infra/resolve-build-scope.sh "$GITHUB_OUTPUT"
  lint:
    steps:
      - run: echo lint
  build-openedx:
    needs: [resolve-build-scope, lint]
    if: ${{ needs.resolve-build-scope.outputs.build_openedx == 'true' }}
    steps:
      - name: Verify OpenEdX build cache health
        run: |
          SUMMARY="${SUMMARY}\n✅ GHA cache exporters intentionally absent for OpenEdX build (docker driver + local image export)"
      - run: timeout 20m "$HOME/.local/bin/syft" scan "docker:${OPENEDX_LOCAL_IMAGE}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
      - name: Verify OpenEdX image branding contract
        run: echo ok
  build-mfe:
    needs: [resolve-build-scope, lint]
    if: ${{ needs.resolve-build-scope.outputs.build_mfe == 'true' }}
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
run_expect_pass "build workflow contract passes with canonical scope routing"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          source ./scripts/lib/lane-normalize.sh\n'
    '          TARGET_ENV_RAW="${{ inputs.target_environment }}"\n'
    '          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"\n'
    '          test -n "$TARGET_ENV"\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing canonical target_environment normalization is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    "  release-bundle:\n    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}\n",
    "  release-bundle:\n    steps:\n      - run: |\n          if [[ \"${{ github.event_name }}\" == \"workflow_dispatch\" ]]; then\n            TARGET_ENV=\"${{ inputs.target_environment }}\"\n            if [[ \"$TARGET_ENV\" == \"select-environment\" ]]; then\n              echo \"target_environment must be explicitly selected before generating a release bundle.\" >&2\n              exit 1\n            fi\n          fi\n",
)
p.write_text(text)
PY
run_expect_fail "release bundle must skip placeholder manual environment instead of failing inside the job"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    "    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' }}\n",
    "    if: ${{ always() && ((github.event_name == 'push' && github.ref == 'refs/heads/main') || (github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment')) }}\n",
)
p.write_text(text)
PY
run_expect_fail "update-gitops must not auto-run on push to main"

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

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"\n',
    '      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"\n'
    '      - run: echo "Mutable tag means dev auto-deploys via ArgoCD"\n',
)
p.write_text(text)
PY
run_expect_fail "stale mutable-tag auto-deploy wording is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace('      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster\n', '')
p.write_text(text)
PY
run_expect_fail "missing lms-ops proof emission is rejected"

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

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace('      - run: ./scripts/infra/resolve-build-scope.sh "$GITHUB_OUTPUT"\n', '')
p.write_text(text)
PY
run_expect_fail "missing build-scope resolver call is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace("    if: ${{ needs.resolve-build-scope.outputs.build_openedx == 'true' }}\n", '')
p.write_text(text)
PY
run_expect_fail "openedx build must stay gated by resolved scope"

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

scope_output="$(printf 'infrastructure/tutor/themes/mereka/mfe/mereka.scss\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `mfe-only`'* ]] || { echo "FAIL classifier should treat MFE theme changes as mfe-only" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `false`'* ]] || { echo "FAIL classifier should skip OpenEdX for MFE-only changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `true`'* ]] || { echo "FAIL classifier should keep MFE enabled for MFE-only changes" >&2; exit 1; }
echo "PASS classifier routes obvious MFE-only changes correctly"

scope_output="$(printf 'deploy/k8s/base/apps/openedx/settings/lms/production.py\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `openedx-only`'* ]] || { echo "FAIL classifier should treat OpenEdX settings changes as openedx-only" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `true`'* ]] || { echo "FAIL classifier should keep OpenEdX enabled for OpenEdX-only changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `false`'* ]] || { echo "FAIL classifier should skip MFE for OpenEdX-only changes" >&2; exit 1; }
echo "PASS classifier routes obvious OpenEdX-only changes correctly"

scope_output="$(printf 'assets/branding/logo.svg\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `both`'* ]] || { echo "FAIL classifier should treat shared branding assets as both" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `true`'* ]] || { echo "FAIL classifier should keep OpenEdX enabled for shared changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `true`'* ]] || { echo "FAIL classifier should keep MFE enabled for shared changes" >&2; exit 1; }
echo "PASS classifier routes shared changes conservatively"

echo "OK"
