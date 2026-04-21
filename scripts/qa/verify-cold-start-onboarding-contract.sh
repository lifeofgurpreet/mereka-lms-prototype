#!/usr/bin/env bash
# @covers AC-CI-ONBOARDING-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify that cold-start onboarding docs, setup scripts, and the heavy bootstrap
# workflow stay aligned.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAILURES=()

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAILURES+=("$1")
}

pass() {
  printf 'PASS: %s\n' "$1"
}

require_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    pass "required path exists: $path"
  else
    fail "required path is missing: $path"
  fi
}

require_executable() {
  local path="$1"
  if [[ -x "$path" ]]; then
    pass "required script is executable: $path"
  else
    fail "required script is not executable: $path"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if rg -q -- "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if rg -q -- "$pattern" "$path"; then
    fail "$label"
  else
    pass "$label"
  fi
}

required_paths=(
  "README.md"
  "docs/guides/onboarding/README.md"
  "docs/guides/onboarding/QUICK_START_LOCAL.md"
  "docs/guides/onboarding/LOCAL_SETUP.md"
  "docs/guides/onboarding/WORKFLOW_LOCAL.md"
  "docs/ops/ci-cd/BENCHMARK_CLASSES.md"
  "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md"
  "infrastructure/tutor/tutor-env.sh"
  "scripts/shared/setup-local.sh"
  "scripts/infra/tutor-config-save.sh"
  "scripts/infra/ensure-buildx-dependency-mirror.sh"
  "scripts/infra/prepare-tutor-build-context.sh"
  "scripts/infra/verify-local-bootstrap-readiness.sh"
  "scripts/infra/build-openedx-image.sh"
  "scripts/infra/build-mfe-image.sh"
  "scripts/qa/verify-setup.sh"
  "docker-bake.hcl"
  ".github/workflows/bootstrap-local-readiness.yml"
  ".github/workflows/build-benchmark.yml"
  "scripts/ci/install-docker-compose.sh"
  "scripts/qa/test-install-docker-compose.sh"
  "infrastructure/tutor/patches/dependency-image-mirrors.sh"
  "scripts/qa/test-dependency-image-mirrors-patch.sh"
  "scripts/qa/test-mfe-npm-install-resilience-patch.sh"
  "scripts/qa/test-mfe-prune-deprecated-shells.sh"
  "infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml"
  "scripts/qa/verify-build-optimizations-render-delta-contract.sh"
  "scripts/qa/test-verify-build-optimizations-render-delta-contract.sh"
)

for path in "${required_paths[@]}"; do
  require_file "$path"
done

printf '\n== Setup script contract ==\n'
require_executable "scripts/shared/setup-local.sh"
require_executable "scripts/infra/ensure-buildx-dependency-mirror.sh"
require_contains "infrastructure/tutor/tutor-env.sh" 'VIRTUAL_ENV' "tutor-env.sh respects an already-active virtualenv"
require_contains "infrastructure/tutor/tutor-env.sh" 'command -v tutor' "tutor-env.sh allows CI-provided Tutor when repo .venv is absent"
require_contains "infrastructure/tutor/tutor-env.sh" 'TUTOR_PLUGINS_ROOT' "tutor-env.sh exports Tutor's native plugin root override"
require_contains "scripts/infra/sync-tutor-plugin-mirror.sh" 'TUTOR_PLUGINS_ROOT' "plugin mirror sync honors Tutor's native plugin root override"
require_contains "scripts/infra/tutor-config-save.sh" 'TUTOR_PLUGINS_ROOT' "tutor-config-save.sh renders against the synced Tutor plugin root"
require_contains "scripts/shared/setup-local.sh" 'dirname "\$\{BASH_SOURCE\[0\]\}"\)/\.\./\.\.' "setup-local.sh resolves repo root from scripts/shared to repo root"
require_contains "scripts/shared/setup-local.sh" '\./scripts/infra/tutor-config-save\.sh' "setup-local.sh uses canonical Tutor config wrapper"
require_contains "scripts/shared/setup-local.sh" '--set MYSQL_ROOT_HOST=%' "setup-local.sh renders MySQL remote-root contract required by local verifier"
require_contains "scripts/shared/setup-local.sh" '--set RUN_MONGODB=true' "setup-local.sh explicitly enables local MongoDB service"
require_contains "scripts/shared/setup-local.sh" '--set RUN_MYSQL=true' "setup-local.sh explicitly enables local MySQL service"
require_contains "scripts/shared/setup-local.sh" '--set RUN_REDIS=true' "setup-local.sh explicitly enables local Redis service"
require_contains "scripts/shared/setup-local.sh" '--set DOCKER_REGISTRY=mirror.gcr.io/' "setup-local.sh uses public mirror registry for local dependency acquisition"
require_contains "scripts/shared/setup-local.sh" '\./scripts/infra/ensure-buildx-dependency-mirror\.sh' "setup-local.sh selects the canonical BuildKit dependency mirror before local image builds"
require_contains "scripts/shared/setup-local.sh" '--set DOCKER_IMAGE_OPENEDX=openedx:nightly' "setup-local.sh points Tutor at the local Open edX image it builds"
require_contains "scripts/shared/setup-local.sh" '--set MFE_DOCKER_IMAGE=openedx-mfe:nightly' "setup-local.sh points Tutor at the local MFE image it builds"
require_contains "scripts/shared/setup-local.sh" '--set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0' "setup-local.sh pins the mirrored current Tutor MySQL image for local bootstrap"
require_contains "scripts/shared/setup-local.sh" '\./scripts/infra/verify-local-bootstrap-readiness\.sh' "setup-local.sh runs local bootstrap readiness verifier"
require_contains "scripts/shared/setup-local.sh" 'LOCAL_ADMIN_PASSWORD' "setup-local.sh supports caller-provided/generated local admin password"
require_contains "scripts/shared/setup-local.sh" 'FORCE_LOCAL_IMAGE_BUILD' "setup-local.sh supports forced local image rebuilds"
require_contains "scripts/shared/setup-local.sh" 'docker image inspect openedx:nightly' "setup-local.sh checks the exact local Open edX image tag"
require_contains "scripts/shared/setup-local.sh" 'docker image inspect openedx-mfe:nightly' "setup-local.sh checks the exact local MFE image tag"
require_contains "infrastructure/tutor/config.example.yml" 'DOCKER_IMAGE_OPENEDX: openedx:nightly' "config.example.yml records the local Open edX image authority"
require_contains "infrastructure/tutor/config.example.yml" 'DOCKER_REGISTRY: mirror.gcr.io/' "config.example.yml records public mirror registry for local dependency acquisition"
require_contains "infrastructure/tutor/config.example.yml" 'RUN_MONGODB: true' "config.example.yml is local-bootstrap compatible for MongoDB"
require_contains "scripts/infra/ensure-buildx-dependency-mirror.sh" 'mirror.gcr.io/moby/buildkit:buildx-stable-1' "BuildKit dependency mirror helper uses a mirrored BuildKit image"
require_contains "scripts/infra/ensure-buildx-dependency-mirror.sh" '\[registry\."docker\.io"\]' "BuildKit dependency mirror helper configures docker.io registry mirror"
require_contains "infrastructure/tutor/apply-patches.sh" 'dependency-image-mirrors\.sh' "canonical Tutor patch path sources dependency image mirror normalization"
require_contains "infrastructure/tutor/apply-patches.sh" 'apply_dependency_image_mirrors_patch' "canonical Tutor patch path applies dependency image mirror normalization"
require_contains "infrastructure/tutor/patches/dependency-image-mirrors.sh" 'mirror.gcr.io/docker/dockerfile:1' "dependency image mirror patch mirrors Dockerfile frontend acquisition"
require_contains "infrastructure/tutor/patches/dependency-image-mirrors.sh" 'mirror.gcr.io/library/ubuntu:22.04' "dependency image mirror patch mirrors Open edX Ubuntu base acquisition"
require_contains "infrastructure/tutor/patches/dependency-image-mirrors.sh" 'mirror.gcr.io/powerman/dockerize:0.19.0' "dependency image mirror patch mirrors Open edX dockerize helper acquisition"
require_contains "infrastructure/tutor/patches/dependency-image-mirrors.sh" 'mirror.gcr.io/library/node:24.11.0-bullseye-slim' "dependency image mirror patch mirrors MFE Node base acquisition"
require_contains "infrastructure/tutor/patches/dependency-image-mirrors.sh" 'revalidate mirror authority' "dependency image mirror patch fails loud on upstream selector drift"
require_contains "docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" 'dependency-image-mirrors\.sh' "Tutor patch inventory documents dependency image mirror normalization"
require_contains "docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" 'temporary compatibility layer' "Tutor patch inventory classifies dependency image mirror normalization as temporary compatibility"
require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'dependency-image mirror normalization' "developer proof matrix names dependency image mirror normalization"
require_contains "infrastructure/tutor/apply-patches.sh" 'apply_mysql_root_host_patch' "canonical Tutor patch path realizes MYSQL_ROOT_HOST in rendered local compose"
require_contains "infrastructure/tutor/apply-patches.sh" 'apply_mfe_npm_install_resilience_patch' "canonical Tutor patch path realizes MFE npm fallback in rendered Dockerfile"
require_file "infrastructure/tutor/patches/mysql-root-host.sh"
require_file "infrastructure/tutor/patches/mfe-npm-install-resilience.sh"
require_contains "infrastructure/tutor/patches/build-optimizations.sh" 'TRANSLATION_SETTINGS_PREFLIGHT' "Open edX patch path owns the production translation settings preflight"
require_contains "infrastructure/tutor/patches/build-optimizations.sh" 'PRODUCTION_BUILD_PROFILE_ARG' "Open edX patch path declares build profile in the production translation stage"
require_contains "infrastructure/tutor/patches/build-optimizations.sh" 'ADVANCED_XBLOCKS_PRODUCTION_COPY' "Open edX patch path carries advanced xblocks before translation discovery"
require_contains "infrastructure/tutor/patches/build-optimizations.sh" 'BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL' "Open edX patch path keeps base/assets uv build isolation normalization"
require_contains "infrastructure/tutor/patches/build-optimizations.sh" 'UWSGI_PIP_INSTALL' "Open edX patch path keeps uwsgi plain-pip fallback"
require_contains "infrastructure/tutor/plugins/_mereka_lms/infrastructure.py" 'caddyfile-mfe-proxy' "MFE Caddy routing extends tutor-mfe's canonical host block"
reject_contains "infrastructure/tutor/plugins/_mereka_lms/infrastructure.py" '\{\{ MFE_HOST \}\}\{\$default_site_port\} \{' "MFE Caddy routing does not emit a duplicate MFE host block"
require_contains "infrastructure/tutor/plugins/_mereka_lms/infrastructure.py" 'CLI_DO_INIT_TASKS' "Mereka theme convergence is source-owned by a Tutor init task"
require_contains "infrastructure/tutor/plugins/_mereka_lms/infrastructure.py" "theme_dir_name='mereka'" "Mereka theme init task converges SiteTheme rows to the Mereka theme"
require_contains "infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py" 'django-csp==3\.8' "repo-built Open edX image installs django-csp for CSPMiddleware"
require_contains "infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py" '\.mereka-built-openedx-image' "repo-built Open edX image carries a runtime dependency sentinel"
require_contains "infrastructure/tutor/plugins/_mereka_lms/lms_settings.py" 'MEREKA_REQUIRE_CSP' "LMS settings fail hard on missing django-csp for repo-built images"
require_contains "infrastructure/tutor/plugins/_mereka_lms/lms_settings.py" 'find_spec\("csp"\)' "LMS settings tolerate upstream bootstrap images without django-csp"
require_contains "infrastructure/tutor/patches/mfe-npm-install-resilience.sh" 'fetch-retries 6' "MFE npm resilience patch preserves npm retry configuration"
require_contains "infrastructure/tutor/patches/mfe-npm-install-resilience.sh" 'Upstream MFE Dockerfile changed; resilience patch selector no longer matches' "MFE npm resilience patch fails loudly on upstream selector drift"
require_contains "infrastructure/tutor/patches/mfe_prune_deprecated_shells.py" 'UPSTREAM_BASE_APT_BLOCK' "MFE post-render cleanup hardens upstream base apt install"
require_contains "infrastructure/tutor/patches/mfe_prune_deprecated_shells.py" 'ARG ENABLE_NEW_RELIC=false' "MFE post-render cleanup prunes build-time New Relic residue"
require_contains "scripts/qa/test-dependency-image-mirrors-patch.sh" 'target-scoped' "dependency image mirror patch has a target-scoped fixture"
require_contains "scripts/qa/test-dependency-image-mirrors-patch.sh" 'idempotent' "dependency image mirror patch has an idempotence fixture"
require_contains "scripts/qa/test-dependency-image-mirrors-patch.sh" 'selector drift' "dependency image mirror patch has a fail-loud selector drift fixture"
require_contains "scripts/qa/test-mfe-npm-install-resilience-patch.sh" 'patch is idempotent' "MFE npm resilience patch has an idempotence fixture"
require_contains "scripts/qa/test-mfe-npm-install-resilience-patch.sh" 'golden Dockerfile transformation' "MFE npm resilience patch has a golden transformation fixture"
require_contains "scripts/qa/test-mfe-prune-deprecated-shells.sh" 'Dockerfile changed on second prune run' "MFE prune helper has an idempotence fixture"
require_contains "docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" 'cold-build compatibility and translation preflight/wrapper surgery' "patch inventory documents residual cold-build compatibility ownership"
require_contains "docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" 'Remaining `build-optimizations.sh` Mutation Ledger' "patch inventory contains the J-exit remaining mutation ledger"
require_contains "infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml" 'default_policy: fail_closed' "build optimization render-delta contract fails closed by default"
require_contains "scripts/qa/verify-build-optimizations-render-delta-contract.sh" 'unexpected added render delta' "build optimization render-delta verifier rejects unlisted additions"
require_contains "scripts/qa/test-verify-build-optimizations-render-delta-contract.sh" 'unexpected render delta fails closed' "build optimization render-delta verifier has seeded negative fixture"
require_contains "infrastructure/tutor/patches" 'TUTOR_ROOT:-\$REPO_ROOT/tutor_env' "Tutor patch modules honor TUTOR_ROOT overrides with repo-local fallback"
require_contains "infrastructure/tutor/plugins/_mereka_lms/lms_settings.py" 'rest_framework.throttling.ScopedRateThrottle' "LMS settings use DRF-owned scoped throttle class"
reject_contains "infrastructure/tutor/plugins/_mereka_lms/lms_settings.py" 'openedx\.core\.lib\.api\.throttle\.ScopedRateThrottle' "LMS settings do not reference removed Open edX throttle module"
reject_contains "infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py" 'mfe-dockerfile-npm-install' "MFE plugin does not register dead Tutor npm-install hook names"
reject_contains "scripts/shared/setup-local.sh" 'apply-patches\.sh' "setup-local.sh does not call legacy low-level patch helper"
reject_contains "scripts/shared/setup-local.sh" 'sync-from-production\.sh' "setup-local.sh does not prompt for production sync"
reject_contains "scripts/shared/setup-local.sh" 'kubectl' "setup-local.sh does not inspect or mutate live clusters"
reject_contains "scripts/shared/setup-local.sh" 'docker images \| grep' "setup-local.sh does not use broad image grep matching"
reject_contains "scripts/shared/setup-local.sh" 'tutor-config-save\.sh.*--quiet|tutor config save.*--quiet' "setup-local.sh does not pass unsupported --quiet to tutor config save"
reject_contains "scripts/shared/setup-local.sh" '-p1EebOQxu' "setup-local.sh does not hardcode Tutor MySQL root password"
reject_contains "scripts/shared/setup-local.sh" 'changeme-local-only' "setup-local.sh does not publish a fixed admin password"

printf '\n== App-cache-cold benchmark contract ==\n'
require_contains "docker-bake.hcl" 'target "openedx-proof-nocache"' "Open edX bake file exposes no-cache proof target"
require_contains "docker-bake.hcl" 'target "mfe-proof-nocache"' "MFE bake file exposes no-cache proof target"
require_contains "scripts/infra/build-openedx-image.sh" '--cache-mode <default\|none>' "Open EdX build helper documents cache-mode"
require_contains "scripts/infra/build-mfe-image.sh" '--cache-mode <default\|none>' "MFE build helper documents cache-mode"
require_contains "scripts/infra/build-openedx-image.sh" 'BAKE_TARGET="\$\{BAKE_TARGET\}-nocache"' "Open EdX build helper can select no-cache bake target"
require_contains "scripts/infra/build-mfe-image.sh" 'BAKE_TARGET="\$\{BAKE_TARGET\}-nocache"' "MFE build helper can select no-cache bake target"
require_contains "scripts/infra/prepare-tutor-build-context-ci.sh" '--set DOCKER_REGISTRY=mirror.gcr.io/' "benchmark Tutor render prep uses public mirror registry for base-image dependency acquisition"
require_contains "scripts/infra/prepare-tutor-build-context-ci.sh" '--set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4' "benchmark Tutor render prep mirrors Caddy base image acquisition"
require_contains ".github/workflows/build-benchmark.yml" '--cache-mode none' "app-cache-cold benchmark passes explicit no-cache mode"
require_contains ".github/workflows/build-benchmark.yml" 'image=mirror.gcr.io/moby/buildkit:buildx-stable-1' "benchmark BuildKit setup avoids anonymous Docker Hub pulls for the BuildKit container"
require_contains ".github/workflows/build-benchmark.yml" '\[registry\."docker\.io"\]' "benchmark BuildKit builder config mirrors Docker Hub dependency acquisition"
require_contains ".github/workflows/build-benchmark.yml" 'mirrors = \["mirror\.gcr\.io"\]' "benchmark BuildKit builder config points Docker Hub pulls at mirror.gcr.io"
require_contains ".github/workflows/build-benchmark.yml" 'proof_class' "benchmark workflow emits a class-safe proof_class field"
require_contains ".github/workflows/build-benchmark.yml" 'benchmark_class=app-cache-cold' "benchmark workflow documents app-cache-cold dispatch"
require_contains ".github/workflows/build-benchmark.yml" 'machine_cold_claim' "benchmark metadata records whether machine-cold is claimed"
require_contains ".github/workflows/build-benchmark.yml" '--output-mode docker' "benchmark build uses local Docker output instead of pushing from read-only proof"
require_contains ".github/workflows/build-benchmark.yml" '--dockerfile "\$\{TUTOR_ROOT\}/env/plugins/mfe/build/mfe/Dockerfile"' "MFE benchmark passes the rendered Dockerfile path"
require_contains ".github/workflows/build-benchmark.yml" 'benchmark build failed; see uploaded benchmark artifact' "benchmark workflow fails the job when a measured build artifact records failure"
reject_contains ".github/workflows/build-benchmark.yml" 'grep -c .* \|\| echo 0' "benchmark layer parser does not write multi-line GitHub outputs on zero matches"

printf '\n== Local setup verifier contract ==\n'
require_contains "scripts/qa/verify-setup.sh" '\./scripts/infra/verify-local-bootstrap-readiness\.sh' "verify-setup.sh delegates initialized-state proof to bootstrap readiness verifier"
reject_contains "scripts/qa/verify-setup.sh" '-p1EebOQxu' "verify-setup.sh does not hardcode Tutor MySQL root password"
reject_contains "scripts/qa/verify-setup.sh" 'django_site WHERE domain LIKE' "verify-setup.sh does not require production tenant site rows for local bootstrap"

printf '\n== Proof workflow contract ==\n'
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'workflow_dispatch:' "bootstrap-local-readiness can be manually dispatched"
require_contains ".github/workflows/bootstrap-local-readiness.yml" "isolated-venv: 'true'" "bootstrap-local-readiness uses an isolated Tutor virtualenv"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'Ensure Docker Compose CLI' "bootstrap-local-readiness provisions Docker Compose when runner image lacks it"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '\./scripts/ci/install-docker-compose\.sh' "bootstrap-local-readiness uses the governed Docker Compose installer helper"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '--set DOCKER_REGISTRY=mirror.gcr.io/' "bootstrap-local-readiness avoids anonymous Docker Hub pulls for overhangio images"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '--set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28' "bootstrap-local-readiness uses a public mirror for MongoDB image pulls"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '--set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0' "bootstrap-local-readiness uses a public mirror for MySQL image pulls"
require_contains "scripts/ci/install-docker-compose.sh" 'DOCKER_COMPOSE_VERSION:-v5\.1\.3' "Docker Compose installer pins the default version"
require_contains "scripts/ci/install-docker-compose.sh" 'sha256sum -c "\$asset\.sha256"' "Docker Compose installer verifies downloaded checksum"
require_contains "scripts/qa/test-install-docker-compose.sh" 'checksum mismatch' "Docker Compose installer has a checksum-failure fixture"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'README\.md' "bootstrap-local-readiness reruns when README changes"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'docs/guides/onboarding/\*\*' "bootstrap-local-readiness reruns when onboarding guides change"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'scripts/shared/setup-local\.sh' "bootstrap-local-readiness reruns when setup-local changes"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'scripts/qa/verify-cold-start-onboarding-contract\.sh' "bootstrap-local-readiness reruns when onboarding contract changes"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '--set MYSQL_ROOT_HOST=%' "bootstrap-local-readiness renders MySQL remote-root contract required by local verifier"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'tutor local launch -I --skip-build' "bootstrap-local-readiness proves first-run Tutor launch path"
require_contains ".github/workflows/bootstrap-local-readiness.yml" '\./scripts/infra/verify-local-bootstrap-readiness\.sh' "bootstrap-local-readiness runs initialized-state verifier"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'config\.redacted\.yml' "bootstrap-local-readiness uploads only a redacted Tutor config snapshot"
require_contains ".github/workflows/bootstrap-local-readiness.yml" 'line.strip\(\) == ""' "bootstrap-local-readiness redacts multi-line secret blocks in Tutor config artifacts"
reject_contains ".github/workflows/bootstrap-local-readiness.yml" 'cp "\$TUTOR_ROOT/config\.yml" var/bootstrap-readiness/config\.yml' "bootstrap-local-readiness does not upload raw Tutor config secrets"

printf '\n== Documentation contract ==\n'
require_contains "README.md" 'verify-cold-start-onboarding-contract\.sh' "README exposes offline cold-start contract verifier"
require_contains "README.md" 'bootstrap-local-readiness\.yml' "README names the heavy bootstrap proof workflow"
require_contains "README.md" 'benchmark_class=app-cache-cold' "README names app-cache-cold image build proof"
reject_contains "README.md" 'README_SETUP\.md' "README does not link missing README_SETUP.md"
reject_contains "README.md" 'DEVELOPER_ONBOARDING\.md' "README does not link missing developer onboarding doc"

require_contains "docs/guides/onboarding/README.md" '2026-04-20' "onboarding index carries current verification date"
require_contains "docs/guides/onboarding/README.md" 'bootstrap-local-readiness\.yml' "onboarding index names heavy proof workflow"
require_contains "docs/guides/onboarding/README.md" 'benchmark_class=app-cache-cold' "onboarding index names app-cache-cold image build proof"
require_contains "docs/guides/onboarding/README.md" 'DEVELOPER_ENVIRONMENT_PROOF_MATRIX\.md' "onboarding index links developer environment proof matrix"

require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" '2026-04-20' "quick start carries current verification date"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'verify-cold-start-onboarding-contract\.sh' "quick start names offline contract verifier"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'verify-local-bootstrap-readiness\.sh' "quick start names local bootstrap readiness verifier"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'bootstrap-local-readiness\.yml' "quick start names heavy proof workflow"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'benchmark_class=app-cache-cold' "quick start names app-cache-cold image build proof"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'FORCE_LOCAL_IMAGE_BUILD=1' "quick start documents forced local image rebuild"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'ensure-buildx-dependency-mirror\.sh' "quick start manual build path selects the BuildKit dependency mirror"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" '--set MYSQL_ROOT_HOST=%' "quick start manual path includes MySQL remote-root contract"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" '--set DOCKER_IMAGE_OPENEDX=openedx:nightly' "quick start manual path points Tutor at the local Open edX image"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" '--set MFE_DOCKER_IMAGE=openedx-mfe:nightly' "quick start manual path points Tutor at the local MFE image"
require_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" '--set RUN_MONGODB=true' "quick start manual path enables local MongoDB"
reject_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'site-down\.md' "quick start does not link missing site-down runbook"
reject_contains "docs/guides/onboarding/QUICK_START_LOCAL.md" 'changeme-local-only' "quick start does not publish fixed local admin password"

require_contains "docs/guides/onboarding/LOCAL_SETUP.md" '2026-04-20' "local setup guide carries current verification date"
require_contains "docs/guides/onboarding/LOCAL_SETUP.md" 'tutor-config-save\.sh' "local setup guide uses canonical Tutor config wrapper"
require_contains "docs/guides/onboarding/LOCAL_SETUP.md" 'prepare-tutor-build-context\.sh' "local setup guide uses canonical build-context wrapper"
require_contains "docs/guides/onboarding/LOCAL_SETUP.md" 'benchmark_class=app-cache-cold' "local setup guide names app-cache-cold image build proof"
require_contains "docs/guides/onboarding/LOCAL_SETUP.md" '--set DOCKER_IMAGE_OPENEDX=openedx:nightly' "local setup guide points Tutor at the local Open edX image"
require_contains "docs/guides/onboarding/LOCAL_SETUP.md" '--set RUN_MONGODB=true' "local setup guide enables local MongoDB"

require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'No lane may quietly become a second Dockerfile, Compose, or manifest generator' "developer environment matrix forbids second generators"
require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'Kubernetes preview' "developer environment matrix reserves k8s preview lane"
require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'Devspace development' "developer environment matrix reserves devspace lane"
require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'durable GHCR BuildKit registry cache' "developer environment matrix classifies durable registry cache"
require_contains "docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md" 'app-level BuildKit cache imports disabled' "developer environment matrix states app-cache-cold semantics"
require_contains "docs/ops/ci-cd/BENCHMARK_CLASSES.md" 'legacy alias' "benchmark classes doc marks true-cold as a legacy alias"
require_contains "docs/ops/ci-cd/BENCHMARK_CLASSES.md" 'app-cache-cold' "benchmark classes doc states current app-cache-cold semantics"
require_contains "docs/ops/ci-cd/BENCHMARK_CLASSES.md" 'does \*\*not\*\* prove a pristine Docker daemon' "benchmark classes doc forbids pristine-daemon overclaim"
require_contains "docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md" 'developer environment matrix' "verifier catalog names developer environment proof matrix"

printf '\n== Markdown link contract ==\n'
if python3 - <<'PY'
from pathlib import Path
from urllib.parse import unquote
import re
import sys

root = Path.cwd()
docs = [
    Path("README.md"),
    Path("docs/guides/onboarding/README.md"),
    Path("docs/guides/onboarding/QUICK_START_LOCAL.md"),
    Path("docs/guides/onboarding/LOCAL_SETUP.md"),
]
pattern = re.compile(r'(?<!!)\[[^\]]+\]\(([^)]+)\)')
broken = []

for doc in docs:
    text = doc.read_text(encoding="utf-8")
    for raw_target in pattern.findall(text):
        target = raw_target.strip()
        if not target or target.startswith("#"):
            continue
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1].strip()
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        target = target.split("#", 1)[0].split("?", 1)[0]
        if not target:
            continue
        target = unquote(target)
        candidate = (root / target.lstrip("/")) if target.startswith("/") else (root / doc.parent / target)
        if not candidate.exists():
            broken.append(f"{doc}: missing link target {raw_target}")

if broken:
    for line in broken:
        print(f"FAIL: {line}", file=sys.stderr)
    sys.exit(1)

print("PASS: selected onboarding markdown links resolve")
PY
then
  pass "selected onboarding markdown links resolve"
else
  fail "selected onboarding markdown links resolve"
fi

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  printf '\nCold-start onboarding contract failed with %s issue(s).\n' "${#FAILURES[@]}" >&2
  exit 1
fi

printf '\nPASS: cold-start onboarding source contract holds.\n'
