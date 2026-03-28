#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-build-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/infra"
mkdir -p "$tmpdir/scripts/qa"
cat >"$tmpdir/scripts/infra/resolve-build-scope.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'build_openedx=true\nbuild_mfe=true\nscope_label=both\n' >> "$1"
EOF
chmod +x "$tmpdir/scripts/infra/resolve-build-scope.sh"
cat >"$tmpdir/scripts/infra/build-openedx-image.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$tmpdir/scripts/infra/build-openedx-image.sh"
cat >"$tmpdir/scripts/qa/verify-openedx-image-branding.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$tmpdir/scripts/qa/verify-openedx-image-branding.sh"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  push:
    branches: [main]
    paths:
      - 'requirements-tutor.txt'
      - '.github/actions/setup-python-env/**'
      - 'infrastructure/tutor/config.example.yml'
      - 'infrastructure/tutor/apply-patches.sh'
      - 'infrastructure/tutor/patches/**'
      - 'infrastructure/tutor/custom-apps/**'
      - 'infrastructure/tutor/plugins/**'
      - 'infrastructure/tutor/themes/**'
      - 'infrastructure/tutor/brand-*/**'
      - 'assets/branding/**'
      - 'scripts/infra/resolve-build-scope.sh'
      - 'scripts/infra/install-cosign.sh'
      - 'scripts/infra/generate-build-provenance.sh'
      - 'scripts/infra/generate-release-bundle.sh'
      - 'scripts/infra/build-openedx-image.sh'
      - 'scripts/infra/release-openedx-gitops.sh'
      - 'scripts/infra/resolve-image-digest.sh'
      - 'scripts/lib/lane-normalize.sh'
      - 'scripts/qa/verify-build-provenance.sh'
      - 'scripts/qa/verify-openedx-image-branding.sh'
      - 'scripts/qa/verify-release-bundle.sh'
      - 'scripts/qa/verify-mfe-image-branding.sh'
      - 'scripts/qa/verify-mfe-runtime-contract.sh'
      - '.github/workflows/build-tutor-images.yml'
      - '!infrastructure/tutor/**/*.md'
      - '!infrastructure/tutor/mfe-build/**'
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
    runs-on: mereka-k8s-heavy-builders
    outputs:
      image_digest: ${{ steps.digest.outputs.digest }}
    steps:
      - name: Verify OpenEdX build cache health
        run: |
          SUMMARY="${SUMMARY}\n✅ GHA cache read/write is enabled for OpenEdX build"
      - name: Build OpenEdX image
        run: |
          ./scripts/infra/build-openedx-image.sh \
            --context-dir tutor_env/env/build/openedx \
            --dockerfile tutor_env/env/build/openedx/Dockerfile \
            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/openedx \
            --primary-tag sha \
            --secondary-tag shortsha \
            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand \
            --mutable-tag mereka-brand
      - name: Resolve pushed openedx digest
        id: digest
        run: echo "digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" >> "$GITHUB_OUTPUT"

  build-mfe:
    needs: [resolve-build-scope, lint]
    if: ${{ needs.resolve-build-scope.outputs.build_mfe == 'true' }}
    runs-on: mereka-k8s-heavy-builders
    outputs:
      image_digest: ${{ steps.digest.outputs.digest }}
    steps:
      - name: Verify MFE build cache health
        run: echo ok
      - name: Tag and push image
        run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/mfe:sha"
      - name: Resolve pushed mfe digest
        id: digest
        run: echo "digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" >> "$GITHUB_OUTPUT"

  scan-openedx-image:
    runs-on: mereka-k8s-runners
    needs: [build-openedx]
    if: ${{ needs.build-openedx.result == 'success' }}
    steps:
      - name: Verify OpenEdX image branding contract
        run: scripts/qa/verify-openedx-image-branding.sh "${OPENEDX_IMAGE_REF}" | tee var/ci/verify-openedx-image-branding.log
        env:
          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}
      - name: Upload OpenEdX branding verification log
        uses: actions/upload-artifact@v4
        with:
          name: openedx-branding-contract-log
          path: var/ci/verify-openedx-image-branding.log
      - name: Generate SBOM for OpenEdX image
        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${OPENEDX_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json
        env:
          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}
      - name: Install Trivy CLI
        run: echo install trivy
      - name: Scan OpenEdX image for vulnerabilities
        run: trivy image "${OPENEDX_IMAGE_REF}"
        env:
          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}

  scan-mfe-image:
    runs-on: mereka-k8s-runners
    needs: [build-mfe]
    if: ${{ needs.build-mfe.result == 'success' }}
    steps:
      - name: Generate SBOM for MFE image
        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${MFE_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}
      - name: Install Trivy CLI
        run: echo install trivy
      - name: Scan MFE image for vulnerabilities
        run: trivy image "${MFE_IMAGE_REF}"
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}

  slsa-provenance:
    needs: [build-openedx, build-mfe]
    steps:
      - run: echo provenance

  release-bundle:
    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]
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
run_expect_pass "build workflow contract passes with scope-aware routing and post-push scan jobs"
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
    "  release-bundle:\n    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]\n    if: ${{ always() && (github.event_name != 'workflow_dispatch' || inputs.target_environment != 'select-environment') }}\n",
    "  release-bundle:\n    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]\n    steps:\n      - run: |\n          if [[ \"${{ github.event_name }}\" == \"workflow_dispatch\" ]]; then\n            TARGET_ENV=\"${{ inputs.target_environment }}\"\n            if [[ \"$TARGET_ENV\" == \"select-environment\" ]]; then\n              echo \"target_environment must be explicitly selected before generating a release bundle.\" >&2\n              exit 1\n            fi\n          fi\n",
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
text = text.replace("      - 'scripts/infra/resolve-build-scope.sh'\n", "")
p.write_text(text)
PY
run_expect_fail "missing exact helper path coverage is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Verify OpenEdX image branding contract\n'
    '        run: scripts/qa/verify-openedx-image-branding.sh "${OPENEDX_IMAGE_REF}" | tee var/ci/verify-openedx-image-branding.log\n'
    '        env:\n'
    '          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing canonical OpenEdX post-push branding verification is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace("      - 'scripts/infra/build-openedx-image.sh'\n", "")
p.write_text(text)
PY
run_expect_fail "missing OpenEdX push-first helper trigger coverage is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Build OpenEdX image\n'
    '        run: |\n'
    '          ./scripts/infra/build-openedx-image.sh \\\n'
    '            --context-dir tutor_env/env/build/openedx \\\n'
    '            --dockerfile tutor_env/env/build/openedx/Dockerfile \\\n'
    '            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/openedx \\\n'
    '            --primary-tag sha \\\n'
    '            --secondary-tag shortsha \\\n'
    '            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand \\\n'
    '            --mutable-tag mereka-brand\n',
    '      - name: Build OpenEdX image\n'
    '        run: tutor images build openedx\n',
)
p.write_text(text)
PY
run_expect_fail "direct tutor images build openedx call is rejected"

# Reintroduce broad scripts/infra glob => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
needle = "      - 'scripts/infra/install-cosign.sh'\n"
text = text.replace(needle, needle + "      - 'scripts/infra/**'\n", 1)
p.write_text(text)
PY
run_expect_fail "broad scripts/infra trigger glob is rejected"

# Drop the doc/provenance exclusion => must fail
write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace("      - '!infrastructure/tutor/**/*.md'\n", "")
p.write_text(text)
PY
run_expect_fail "missing tutor markdown exclusion is rejected"

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

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Verify OpenEdX build cache health\n'
    '        run: |\n'
    '          SUMMARY="${SUMMARY}\\n✅ GHA cache read/write is enabled for OpenEdX build"\n',
    '      - name: Verify OpenEdX build cache health\n'
    '        run: |\n'
    '          SUMMARY="${SUMMARY}\\n❌ GHA cache read/write flags NOT found in OpenEdX build command"\n',
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
text = text.replace("      - 'scripts/qa/verify-mfe-runtime-contract.sh'\n", "")
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
    '      - name: Generate SBOM for OpenEdX image\n'
    '        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${OPENEDX_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n',
    '      - name: Generate SBOM for OpenEdX image\n'
    '        run: "$HOME/.local/bin/syft" scan "registry:${OPENEDX_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n',
)
p.write_text(text)
PY
run_expect_fail "OpenEdX post-push SBOM generation must stay timeout-guarded"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Generate SBOM for OpenEdX image\n'
    '        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${OPENEDX_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n'
    '        env:\n'
    '          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}\n'
    '      - name: Install Trivy CLI\n'
    '        run: echo install trivy\n'
    '      - name: Scan OpenEdX image for vulnerabilities\n'
    '        run: trivy image "${OPENEDX_IMAGE_REF}"\n'
    '        env:\n'
    '          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}\n',
    '',
)
text = text.replace(
    '      - name: Verify OpenEdX image branding contract\n'
    '        run: echo ok\n',
    '      - name: Verify OpenEdX image branding contract\n'
    '        run: echo ok\n'
    '      - name: Generate SBOM for OpenEdX image\n'
    '        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${OPENEDX_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-openedx.cdx.json\n',
)
p.write_text(text)
PY
run_expect_fail "OpenEdX heavy build job must not host post-push scan steps"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    "  release-bundle:\n    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]\n",
    "  release-bundle:\n    needs: [build-openedx, build-mfe, slsa-provenance]\n",
)
p.write_text(text)
PY
run_expect_fail "release bundle must wait for post-push scan jobs"

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
