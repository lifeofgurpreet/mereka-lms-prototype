#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-workflow-contract.sh"
SCOPE_MODE="${TEST_VERIFY_BUILD_WORKFLOW_CONTRACT_SCOPE:-}"
CHANGED_FILES_RAW="${TEST_VERIFY_BUILD_WORKFLOW_CONTRACT_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

tmpdir="$(mktemp -d -t verify-build-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

should_skip_scope() {
  local changed_path

  if [[ "$SCOPE_MODE" != "changed" ]]; then
    return 1
  fi

  if [[ -z "${CHANGED_FILES_RAW//[[:space:]]/}" ]]; then
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -z "$changed_path" ]] && continue
    case "$changed_path" in
      .github/workflows/build-tutor-images.yml|\
      .github/actions/select-build-lane/*|\
      scripts/infra/build-openedx-image.sh|\
      scripts/infra/build-mfe-image.sh|\
      scripts/infra/prepare-tutor-build-context.sh|\
      scripts/infra/prepare-tutor-build-context-ci.sh|\
      scripts/infra/resolve-build-scope.sh|\
      scripts/infra/install-cosign.sh|\
      scripts/infra/install-trivy.sh|\
      scripts/infra/generate-build-provenance.sh|\
      scripts/infra/generate-release-bundle.sh|\
      scripts/infra/release-openedx-gitops.sh|\
      scripts/infra/resolve-image-digest.sh|\
      scripts/lib/lane-normalize.sh|\
      scripts/release/generate_release_object.py|\
      scripts/release/release_object_bindings.py|\
      scripts/qa/verify-build-workflow-contract.sh|\
      scripts/qa/test-verify-build-workflow-contract.sh|\
      scripts/qa/verify-build-provenance.sh|\
      scripts/qa/verify-openedx-image-branding.sh|\
      scripts/qa/verify-mfe-image-branding.sh|\
      scripts/qa/verify-mfe-runtime-contract.sh|\
      scripts/qa/verify-release-bundle.sh|\
      scripts/qa/verify-release-object.sh)
        return 1
        ;;
    esac
  done <<<"$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS test-verify-build-workflow-contract (scope skip: no build-workflow-contract-relevant changes)"
  exit 0
fi

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/.github/actions/select-build-lane" "$tmpdir/scripts/infra"
mkdir -p "$tmpdir/scripts/qa"
cat >"$tmpdir/.github/actions/select-build-lane/action.yml" <<'EOF'
name: select-build-lane
outputs:
  runner_label:
    value: ${{ steps.select.outputs.runner_label }}
runs:
  using: composite
  steps:
    - id: select
      shell: bash
      run: echo "runner_label=mereka-k8s-heavy-builders" >> "$GITHUB_OUTPUT"
EOF
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
cat >"$tmpdir/scripts/infra/build-mfe-image.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$tmpdir/scripts/infra/build-mfe-image.sh"
cat >"$tmpdir/scripts/infra/prepare-tutor-build-context.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$tmpdir/scripts/infra/prepare-tutor-build-context.sh"
cat >"$tmpdir/scripts/infra/prepare-tutor-build-context-ci.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
chmod +x "$tmpdir/scripts/infra/prepare-tutor-build-context-ci.sh"
cat >"$tmpdir/scripts/qa/verify-openedx-image-branding.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DOCKER_PULL_TIMEOUT_SECS="${DOCKER_PULL_TIMEOUT_SECS:-600}"
DOCKER_RUN_TIMEOUT_SECS="${DOCKER_RUN_TIMEOUT_SECS:-180}"
run_with_timeout() { timeout "$1" "${@:2}"; }
run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull example >/dev/null || true
run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run example true || true
echo "ok"
EOF
chmod +x "$tmpdir/scripts/qa/verify-openedx-image-branding.sh"
cat >"$tmpdir/scripts/qa/verify-mfe-image-branding.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DOCKER_PULL_TIMEOUT_SECS="${DOCKER_PULL_TIMEOUT_SECS:-600}"
DOCKER_RUN_TIMEOUT_SECS="${DOCKER_RUN_TIMEOUT_SECS:-180}"
run_with_timeout() { timeout "$1" "${@:2}"; }
run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull example >/dev/null || true
run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run example true || true
echo "ok"
EOF
chmod +x "$tmpdir/scripts/qa/verify-mfe-image-branding.sh"

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
      - 'scripts/infra/prepare-tutor-build-context.sh'
      - 'scripts/infra/prepare-tutor-build-context-ci.sh'
      - 'scripts/infra/resolve-build-scope.sh'
      - 'scripts/infra/install-cosign.sh'
      - 'scripts/infra/install-trivy.sh'
      - 'scripts/infra/generate-build-provenance.sh'
      - 'scripts/infra/generate-release-bundle.sh'
      - 'scripts/release/generate_release_object.py'
      - 'scripts/release/release_object_bindings.py'
      - 'scripts/infra/build-openedx-image.sh'
      - 'scripts/infra/build-mfe-image.sh'
      - 'scripts/infra/release-openedx-gitops.sh'
      - 'scripts/infra/resolve-image-digest.sh'
      - 'scripts/lib/lane-normalize.sh'
      - 'scripts/qa/verify-build-provenance.sh'
      - 'scripts/qa/verify-openedx-image-branding.sh'
      - 'scripts/qa/verify-release-bundle.sh'
      - 'scripts/qa/verify-release-object.sh'
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
      build_profile:
        type: choice
        options: [proof, fast]
        default: proof
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
  select-build-lane:
    runs-on: ubuntu-latest
    outputs:
      runner_label: ${{ steps.select.outputs.runner_label }}
    steps:
      - uses: actions/checkout@v4
      - id: select
        uses: ./.github/actions/select-build-lane
  prepare-build-context:
    runs-on: mereka-k8s-runners
    needs: [resolve-build-scope, lint]
    if: ${{ needs.resolve-build-scope.outputs.build_openedx == 'true' || needs.resolve-build-scope.outputs.build_mfe == 'true' }}
    steps:
      - name: Set up Python environment
        uses: ./.github/actions/setup-python-env
      - id: prep-target
        env:
          BUILD_OPENEDX: ${{ needs.resolve-build-scope.outputs.build_openedx }}
          BUILD_MFE: ${{ needs.resolve-build-scope.outputs.build_mfe }}
        run: |
          if [[ "$BUILD_OPENEDX" == 'true' && "$BUILD_MFE" == 'true' ]]; then
            echo "target=all" >> "$GITHUB_OUTPUT"
          elif [[ "$BUILD_OPENEDX" == 'true' ]]; then
            echo "target=openedx" >> "$GITHUB_OUTPUT"
          elif [[ "$BUILD_MFE" == 'true' ]]; then
            echo "target=mfe" >> "$GITHUB_OUTPUT"
          else
            echo "No Tutor build context requested." >&2
            exit 1
          fi
      - run: |
          ./scripts/infra/prepare-tutor-build-context-ci.sh --target "${{ steps.prep-target.outputs.target }}"
          tar -C tutor_env/env/build -czf var/ci/openedx-build-context.tgz openedx
          tar -C tutor_env/env/plugins/mfe/build -czf var/ci/mfe-build-context.tgz mfe
      - uses: actions/upload-artifact@v4
        with:
          name: tutor-build-contexts
          path: var/ci/

  build-openedx:
    needs: [resolve-build-scope, lint, select-build-lane, prepare-build-context]
    if: ${{ needs.resolve-build-scope.outputs.build_openedx == 'true' }}
    runs-on: ${{ needs.select-build-lane.outputs.runner_label }}
    outputs:
      image_digest: ${{ steps.digest.outputs.digest }}
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: tutor-build-contexts
          path: var/ci
      - run: |
          mkdir -p tutor_env/env/build
          tar -C tutor_env/env/build -xzf var/ci/openedx-build-context.tgz
      - name: Verify OpenEdX build cache health
        run: |
          SUMMARY="${SUMMARY}\n✅ GHA cache read/write is enabled for OpenEdX build"
      - name: Build OpenEdX image
        run: |
          BUILD_PROFILE="proof"
          ./scripts/infra/build-openedx-image.sh \
            --context-dir tutor_env/env/build/openedx \
            --dockerfile tutor_env/env/build/openedx/Dockerfile \
            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/openedx \
            --primary-tag sha \
            --secondary-tag shortsha \
            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand \
            --build-profile "${BUILD_PROFILE}" \
            --mutable-tag mereka-brand
      - name: Resolve pushed openedx digest
        id: digest
        run: echo "digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" >> "$GITHUB_OUTPUT"

  build-mfe:
    needs: [resolve-build-scope, lint, select-build-lane, prepare-build-context]
    if: ${{ needs.resolve-build-scope.outputs.build_mfe == 'true' }}
    runs-on: ${{ needs.select-build-lane.outputs.runner_label }}
    outputs:
      image_digest: ${{ steps.digest.outputs.digest }}
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: tutor-build-contexts
          path: var/ci
      - run: |
          mkdir -p tutor_env/env/plugins/mfe/build
          tar -C tutor_env/env/plugins/mfe/build -xzf var/ci/mfe-build-context.tgz
      - name: Verify MFE build cache health
        run: echo ok
      - name: Build MFE image
        run: |
          BUILD_PROFILE="proof"
          ./scripts/infra/build-mfe-image.sh \
            --context-dir tutor_env/env/plugins/mfe/build/mfe \
            --dockerfile tutor_env/env/plugins/mfe/build/mfe/Dockerfile \
            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/mfe \
            --primary-tag sha \
            --secondary-tag shortsha \
            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/mfe:mereka-brand \
            --build-profile "${BUILD_PROFILE}" \
            --mutable-tag mereka-brand
      - name: Resolve pushed mfe digest
        id: digest
        run: echo "digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" >> "$GITHUB_OUTPUT"

  scan-openedx-image:
    runs-on: mereka-k8s-heavy-builders
    needs: [build-openedx]
    if: ${{ needs.build-openedx.result == 'success' }}
    steps:
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4
      - name: Fix DinD network MTU
        run: echo fix mtu
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
        run: |
          set +e
          timeout 20m trivy image "${OPENEDX_IMAGE_REF}"
          trivy_status=$?
          set -e
          if [[ "$trivy_status" -eq 124 ]]; then
            echo "OpenEdX Trivy scan timed out after 20m; continuing without vulnerability verdict." >&2
            exit 124
          fi
          if [[ "$trivy_status" -ne 0 ]]; then
            echo "OpenEdX Trivy scan failed with exit code ${trivy_status}; continuing without vulnerability verdict." >&2
            exit "$trivy_status"
          fi
        env:
          OPENEDX_IMAGE_REF: ${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}

  scan-mfe-image:
    runs-on: mereka-k8s-heavy-builders
    needs: [build-mfe]
    if: ${{ needs.build-mfe.result == 'success' }}
    steps:
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4
      - name: Fix DinD network MTU
        run: echo fix mtu
      - name: Verify MFE image branding contract
        run: scripts/qa/verify-mfe-image-branding.sh "${MFE_IMAGE_REF}" | tee var/ci/verify-mfe-image-branding.log
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}
      - name: Upload MFE branding verification log
        uses: actions/upload-artifact@v4
        with:
          name: mfe-branding-contract-log
          path: var/ci/verify-mfe-image-branding.log
      - name: Verify MFE runtime contract (image)
        run: scripts/qa/verify-mfe-runtime-contract.sh --image "${MFE_IMAGE_REF}" | tee var/ci/verify-mfe-runtime-contract.log
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}
      - name: Upload MFE runtime contract log
        uses: actions/upload-artifact@v4
        with:
          name: mfe-runtime-contract-log
          path: var/ci/verify-mfe-runtime-contract.log
      - name: Generate SBOM for MFE image
        run: timeout 20m "$HOME/.local/bin/syft" scan "registry:${MFE_IMAGE_REF}" -o cyclonedx-json=var/ci/sbom-mfe.cdx.json
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}
      - name: Install Trivy CLI
        run: echo install trivy
      - name: Scan MFE image for vulnerabilities
        run: |
          set +e
          timeout 20m trivy image "${MFE_IMAGE_REF}"
          trivy_status=$?
          set -e
          if [[ "$trivy_status" -eq 124 ]]; then
            echo "MFE Trivy scan timed out after 20m; continuing without vulnerability verdict." >&2
            exit 124
          fi
          if [[ "$trivy_status" -ne 0 ]]; then
            echo "MFE Trivy scan failed with exit code ${trivy_status}; continuing without vulnerability verdict." >&2
            exit "$trivy_status"
          fi
        env:
          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}

  slsa-provenance:
    needs: [build-openedx, build-mfe]
    steps:
      - run: echo provenance

  release-bundle:
    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || (inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof')) }}
    steps:
      - run: ./scripts/infra/generate-release-bundle.sh --output var/ci/release-bundle.json --repo Biji-Biji-Initiative/mereka-lms --commit-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --workflow .github/workflows/build-tutor-images.yml --run-id 1 --run-attempt 1 --target-environment dev --openedx-image ghcr.io/biji-biji-initiative/mereka-lms/openedx --openedx-digest sha256:1111111111111111111111111111111111111111111111111111111111111111 --mfe-image ghcr.io/biji-biji-initiative/mereka-lms/mfe --mfe-digest sha256:2222222222222222222222222222222222222222222222222222222222222222
      - run: ./scripts/qa/verify-release-bundle.sh var/ci/release-bundle.json
      - run: python3 ./scripts/release/generate_release_object.py --release-bundle-json var/ci/release-bundle.json --output var/ci/release-object.json
      - run: ./scripts/qa/verify-release-object.sh var/ci/release-object.json
      - uses: actions/upload-artifact@v4
        with:
          name: release-bundle
          path: |
            var/ci/release-bundle.json
            var/ci/release-object.json
            var/ci/release-bundle.sig
            var/ci/release-bundle.pem
      - run: |
          python3 - <<'PY'
          files = [
            "contracts/release-contracts.yaml",
            "contracts/release-bundle-schema.yaml",
            "contracts/promotion-dispatch-envelope-schema.yaml",
          ]
          print(files)
          PY

  dispatch-dev-promotion:
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    steps:
      - run: |
          python3 - <<'PY'
          bundle_id = "rb-aaaaaaaa-20260410T120000Z"
          contract_family = "promotion_dispatch_envelope_schema"
          contract_version = "1.0"
          contract_ref = "Biji-Biji-Initiative/platform-control-plane@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
          evidence = {
              "release_bundle_id": bundle_id,
              "lane": "mereka-lms",
              "delivery_lane": "dev",
              "service_id": "mereka-lms",
              "dispatch_event_type": "promote-mereka-lms-dev",
              "created_at": "2026-04-10T12:00:00Z",
              "validation_evidence": "ci-build-pass:1",
              "release_object": {
                  "schema_version": "release-object/v1",
                  "release_id": "ro-rb-aaaaaaaa-20260410T120000Z",
                  "service_id": "mereka-lms",
                  "app_commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "build": {"release_bundle_id": bundle_id},
              },
              "build_provenance": {
                  "run_url": "https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/1",
                  "artifact_uri": "actions/artifacts/release-bundle@run-1",
                  "build_commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
              },
              "control_plane_ref": contract_ref,
              "contract_family": contract_family,
              "contract_version": contract_version,
              "contract_ref": contract_ref,
          }
          payload = {
              "event_type": evidence["dispatch_event_type"],
              "client_payload": evidence,
          }
          print(payload)
          PY

  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof' }}
    steps:
      - run: |
          source ./scripts/lib/lane-normalize.sh
          TARGET_ENV_RAW="${{ inputs.target_environment }}"
          TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV_RAW}")"
          test -n "$TARGET_ENV"
      - run: ./scripts/qa/verify-release-object.sh var/ci/release-object.json
      - run: |
          python3 ./scripts/release/release_object_bindings.py \
            promotion-inputs \
            --release-object-json var/ci/release-object.json \
            --target-env production \
            --openedx-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
            --mfe-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
            --app-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >/dev/null
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: |
          ./scripts/infra/release-openedx-gitops.sh \
            --target-env production \
            --openedx-tag sha \
            --mfe-tag sha \
            --openedx-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
            --mfe-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
            --release-object-json var/ci/release-object.json \
            --require-digests \
            --app-repo "$GITHUB_WORKSPACE" \
            --infra-repo "$GITHUB_WORKSPACE/bbi-infrastructure" \
            --apply --commit --push
      - run: |
          ./bin/lms-ops proof \
            --concern release-gate \
            --lane prod \
            --release-object-json var/ci/release-object.json \
            --skip-cluster
      - run: |
          python3 ./scripts/release/release_object_bindings.py \
            verify-proof-envelope \
            --envelope-json var/proof/release-gate.json \
            --release-object-json var/ci/release-object.json
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
  if ! REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-build-workflow-contract.out 2>&1; then
    echo "FAIL ${label}: expected pass but command failed" >&2
    cat /tmp/verify-build-workflow-contract.out >&2 || true
    exit 1
  fi
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
    "  release-bundle:\n    needs: [build-openedx, build-mfe, scan-openedx-image, scan-mfe-image, slsa-provenance]\n    if: ${{ always() && (github.event_name != 'workflow_dispatch' || (inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof')) }}\n",
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
    '      - name: Set up Docker Buildx\n'
    '        uses: docker/setup-buildx-action@v4\n',
    '',
    1,
)
p.write_text(text)
PY
run_expect_fail "OpenEdX post-push scan must establish Docker runtime"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Build OpenEdX image\n'
    '        run: |\n'
    '          BUILD_PROFILE="proof"\n'
    '          ./scripts/infra/build-openedx-image.sh \\\n'
    '            --context-dir tutor_env/env/build/openedx \\\n'
    '            --dockerfile tutor_env/env/build/openedx/Dockerfile \\\n'
    '            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/openedx \\\n'
    '            --primary-tag sha \\\n'
    '            --secondary-tag shortsha \\\n'
    '            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand \\\n'
    '            --build-profile "${BUILD_PROFILE}" \\\n'
    '            --mutable-tag mereka-brand\n',
    '      - name: Build OpenEdX image\n'
    '        run: tutor images build openedx\n',
)
p.write_text(text)
PY
run_expect_fail "direct tutor images build openedx call is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace("      - 'scripts/infra/build-mfe-image.sh'\n", "")
p.write_text(text)
PY
run_expect_fail "missing MFE push-first helper trigger coverage is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Build MFE image\n'
    '        run: |\n'
    '          BUILD_PROFILE="proof"\n'
    '          ./scripts/infra/build-mfe-image.sh \\\n'
    '            --context-dir tutor_env/env/plugins/mfe/build/mfe \\\n'
    '            --dockerfile tutor_env/env/plugins/mfe/build/mfe/Dockerfile \\\n'
    '            --image-repo ghcr.io/biji-biji-initiative/mereka-lms/mfe \\\n'
    '            --primary-tag sha \\\n'
    '            --secondary-tag shortsha \\\n'
    '            --cache-ref ghcr.io/biji-biji-initiative/mereka-lms/mfe:mereka-brand \\\n'
    '            --build-profile "${BUILD_PROFILE}" \\\n'
    '            --mutable-tag mereka-brand\n',
    '      - name: Build MFE image\n'
    '        run: tutor images build mfe\n',
)
p.write_text(text)
PY
run_expect_fail "direct tutor images build mfe call is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Verify MFE image branding contract\n'
    '        run: scripts/qa/verify-mfe-image-branding.sh "${MFE_IMAGE_REF}" | tee var/ci/verify-mfe-image-branding.log\n'
    '        env:\n'
    '          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}\n'
    '      - name: Upload MFE branding verification log\n'
    '        uses: actions/upload-artifact@v4\n'
    '        with:\n'
    '          name: mfe-branding-contract-log\n'
    '          path: var/ci/verify-mfe-image-branding.log\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing canonical MFE post-push branding verification is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
marker = (
    '      - name: Set up Docker Buildx\n'
    '        uses: docker/setup-buildx-action@v4\n'
    '      - name: Fix DinD network MTU\n'
    '        run: echo fix mtu\n'
)
text = text.replace(marker, '', 1)
p.write_text(text)
PY
run_expect_fail "MFE post-push scan must establish Docker runtime"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - name: Verify MFE runtime contract (image)\n'
    '        run: scripts/qa/verify-mfe-runtime-contract.sh --image "${MFE_IMAGE_REF}" | tee var/ci/verify-mfe-runtime-contract.log\n'
    '        env:\n'
    '          MFE_IMAGE_REF: ${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}\n'
    '      - name: Upload MFE runtime contract log\n'
    '        uses: actions/upload-artifact@v4\n'
    '        with:\n'
    '          name: mfe-runtime-contract-log\n'
    '          path: var/ci/verify-mfe-runtime-contract.log\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing canonical MFE post-push runtime verification is rejected"

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
    if: ${{ always() && (github.event_name != 'workflow_dispatch' || (inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof')) }}
  update-gitops:
    runs-on: ubuntu-latest
    if: ${{ always() && ((github.event_name == 'push' && github.ref == 'refs/heads/main') || (github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof')) }}
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
text = text.replace('      - run: ./scripts/qa/verify-release-object.sh var/ci/release-object.json\n', '')
p.write_text(text)
PY
run_expect_fail "missing release object consumer verification gate is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          python3 ./scripts/release/release_object_bindings.py \\\n'
    '            promotion-inputs \\\n'
    '            --release-object-json var/ci/release-object.json \\\n'
    '            --target-env production \\\n'
    '            --openedx-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \\\n'
    '            --mfe-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \\\n'
    '            --app-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >/dev/null\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing promotion-inputs release object consumer gate is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          ./scripts/infra/release-openedx-gitops.sh \\\n'
    '            --target-env production \\\n'
    '            --openedx-tag sha \\\n'
    '            --mfe-tag sha \\\n'
    '            --openedx-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \\\n'
    '            --mfe-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \\\n'
    '            --release-object-json var/ci/release-object.json \\\n'
    '            --require-digests \\\n'
    '            --app-repo "$GITHUB_WORKSPACE" \\\n'
    '            --infra-repo "$GITHUB_WORKSPACE/bbi-infrastructure" \\\n'
    '            --apply --commit --push\n',
    '      - run: |\n'
    '          ./scripts/infra/release-openedx-gitops.sh \\\n'
    '            --target-env production \\\n'
    '            --openedx-tag sha \\\n'
    '            --mfe-tag sha \\\n'
    '            --openedx-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \\\n'
    '            --mfe-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \\\n'
    '            --require-digests \\\n'
    '            --app-repo "$GITHUB_WORKSPACE" \\\n'
    '            --infra-repo "$GITHUB_WORKSPACE/bbi-infrastructure" \\\n'
    '            --apply --commit --push\n',
)
p.write_text(text)
PY
run_expect_fail "missing release-object binding on promotion step is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          ./bin/lms-ops proof \\\n'
    '            --concern release-gate \\\n'
    '            --lane prod \\\n'
    '            --release-object-json var/ci/release-object.json \\\n'
    '            --skip-cluster\n',
    '      - run: |\n'
    '          ./bin/lms-ops proof \\\n'
    '            --concern release-gate \\\n'
    '            --lane prod \\\n'
    '            --skip-cluster\n',
)
p.write_text(text)
PY
run_expect_fail "missing release-object binding on proof step is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          ./bin/lms-ops proof \\\n'
    '            --concern release-gate \\\n'
    '            --lane prod \\\n'
    '            --release-object-json var/ci/release-object.json \\\n'
    '            --skip-cluster\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing lms-ops proof emission is rejected"

write_pass_fixture
python3 - "$tmpdir" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / ".github/workflows/build-tutor-images.yml"
text = p.read_text()
text = text.replace(
    '      - run: |\n'
    '          python3 ./scripts/release/release_object_bindings.py \\\n'
    '            verify-proof-envelope \\\n'
    '            --envelope-json var/proof/release-gate.json \\\n'
    '            --release-object-json var/ci/release-object.json\n',
    '',
)
p.write_text(text)
PY
run_expect_fail "missing proof-envelope release binding verification is rejected"

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
    '        run: |\n'
    '          set +e\n'
    '          timeout 20m trivy image "${OPENEDX_IMAGE_REF}"\n'
    '          trivy_status=$?\n'
    '          set -e\n'
    '          if [[ "$trivy_status" -eq 124 ]]; then\n'
    '            echo "OpenEdX Trivy scan timed out after 20m; continuing without vulnerability verdict." >&2\n'
    '            exit 124\n'
    '          fi\n'
    '          if [[ "$trivy_status" -ne 0 ]]; then\n'
    '            echo "OpenEdX Trivy scan failed with exit code ${trivy_status}; continuing without vulnerability verdict." >&2\n'
    '            exit "$trivy_status"\n'
    '          fi\n'
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

scope_output="$(printf 'scripts/infra/build-openedx-image.sh\nscripts/qa/verify-openedx-image-branding.sh\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `openedx-only`'* ]] || { echo "FAIL classifier should treat OpenEdX build helper and verifier changes as openedx-only" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `true`'* ]] || { echo "FAIL classifier should keep OpenEdX enabled for OpenEdX build helper and verifier changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `false`'* ]] || { echo "FAIL classifier should skip MFE for OpenEdX build helper and verifier changes" >&2; exit 1; }
echo "PASS classifier routes OpenEdX helper and verifier changes correctly"

scope_output="$(printf 'scripts/infra/build-mfe-image.sh\nscripts/qa/verify-mfe-image-branding.sh\nscripts/qa/verify-mfe-runtime-contract.sh\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `mfe-only`'* ]] || { echo "FAIL classifier should treat MFE build helper and verifier changes as mfe-only" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `false`'* ]] || { echo "FAIL classifier should skip OpenEdX for MFE build helper and verifier changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `true`'* ]] || { echo "FAIL classifier should keep MFE enabled for MFE build helper and verifier changes" >&2; exit 1; }
echo "PASS classifier routes MFE helper and verifier changes correctly"

scope_output="$(printf 'assets/branding/logo.svg\n' | bash "$ROOT_DIR/scripts/infra/resolve-build-scope.sh")"
[[ "$scope_output" == *'Scope label: `both`'* ]] || { echo "FAIL classifier should treat shared branding assets as both" >&2; exit 1; }
[[ "$scope_output" == *'Build OpenEdX: `true`'* ]] || { echo "FAIL classifier should keep OpenEdX enabled for shared changes" >&2; exit 1; }
[[ "$scope_output" == *'Build MFE: `true`'* ]] || { echo "FAIL classifier should keep MFE enabled for shared changes" >&2; exit 1; }
echo "PASS classifier routes shared changes conservatively"

echo "OK"
