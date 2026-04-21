#!/usr/bin/env bash
# @covers AC-CI-BOOTSTRAP-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify bootstrap-local-readiness.yml contract:
#   - workflow exists and is serialized on a governed bootstrap runner lane
#   - canonical Tutor config and bootstrap-readiness front doors are used
#   - CI dependency acquisition uses public mirror.gcr.io image refs, not anonymous Docker Hub pulls
#   - rendered local Compose images are resolved and pulled before launch
#   - provenance is checked against actual running tutor_local container images
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BOOTSTRAP_WF="${BOOTSTRAP_WF_OVERRIDE:-$REPO_ROOT/.github/workflows/bootstrap-local-readiness.yml}"
CONFIG_FRONT_DOOR="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
READINESS_SCRIPT="$REPO_ROOT/scripts/infra/verify-local-bootstrap-readiness.sh"
COMPOSE_INSTALLER="$REPO_ROOT/scripts/ci/install-docker-compose.sh"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Bootstrap Workflow Contract ==="

if [[ ! -f "$BOOTSTRAP_WF" ]]; then
  fail "bootstrap-local-readiness.yml not found"
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
pass "bootstrap-local-readiness.yml exists"

if [[ -x "$CONFIG_FRONT_DOOR" ]]; then
  pass "tutor-config-save front door exists"
else
  fail "tutor-config-save front door missing or not executable"
fi

if [[ -x "$READINESS_SCRIPT" ]]; then
  pass "verify-local-bootstrap-readiness front door exists"
else
  fail "verify-local-bootstrap-readiness front door missing or not executable"
fi

if [[ -x "$COMPOSE_INSTALLER" ]]; then
  pass "Docker Compose installer front door exists"
else
  fail "Docker Compose installer front door missing or not executable"
fi

if grep -q '^  workflow_dispatch:' "$BOOTSTRAP_WF"; then
  pass "workflow supports manual bootstrap dispatch"
else
  fail "workflow missing workflow_dispatch trigger"
fi

if grep -q 'group: bootstrap-local-readiness' "$BOOTSTRAP_WF" \
  && grep -q 'cancel-in-progress: false' "$BOOTSTRAP_WF"; then
  pass "workflow serializes bootstrap lane without cancelling in-flight runs"
else
  fail "workflow missing serialized bootstrap concurrency contract"
fi

if grep -q '^  select-bootstrap-lane:' "$BOOTSTRAP_WF" \
  && grep -q 'uses: Biji-Biji-Initiative/bbi-infrastructure/.github/actions/select-runner-lane@main' "$BOOTSTRAP_WF" \
  && grep -q 'fallback_label: mereka-k8s-heavy-builders' "$BOOTSTRAP_WF" \
  && grep -Fq 'runs-on: ${{ needs.select-bootstrap-lane.outputs.runner_label }}' "$BOOTSTRAP_WF"; then
  pass "workflow routes local bootstrap through governed runner-lane selection with heavy-builder fallback"
else
  fail "workflow missing governed bootstrap runner-lane contract"
fi

if grep -q 'Pre-clean persistent Tutor workspace' "$BOOTSTRAP_WF" \
  && grep -q 'cleanup_workspace_paths()' "$BOOTSTRAP_WF" \
  && grep -q 'timeout 30s docker info' "$BOOTSTRAP_WF" \
  && grep -q 'timeout 2m docker run --rm' "$BOOTSTRAP_WF" \
  && grep -q -- '--network none' "$BOOTSTRAP_WF" \
  && grep -q 'mirror.gcr.io/library/alpine:3.20' "$BOOTSTRAP_WF" \
  && grep -q 'tutor_env|var/bootstrap-readiness|var/ci|.buildx-cache' "$BOOTSTRAP_WF" \
  && grep -q 'sudo -n true' "$BOOTSTRAP_WF" \
  && grep -q 'sudo rm -r[f] --one-file-system "\$target"' "$BOOTSTRAP_WF" \
  && grep -q '^[[:space:]]*rm -r[f] --one-file-system "\$target"' "$BOOTSTRAP_WF" \
  && grep -q 'cleanup_workspace_paths tutor_env var/bootstrap-readiness var/ci .buildx-cache' "$BOOTSTRAP_WF"; then
  pass "workflow pre-cleans generated Tutor state before checkout with Docker-root and non-interactive sudo fallbacks"
else
  fail "workflow missing pre-checkout persistent Tutor workspace cleanup with Docker-root/sudo fallback"
fi

if grep -q './scripts/infra/tutor-config-save.sh' "$BOOTSTRAP_WF"; then
  pass "workflow renders config through canonical tutor-config-save front door"
else
  fail "workflow missing canonical tutor-config-save invocation"
fi

if grep -q -- '--set DOCKER_REGISTRY=mirror.gcr.io/' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_MEILISEARCH=mirror.gcr.io/getmeili/meilisearch:v1.8.4' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_REDIS=mirror.gcr.io/library/redis:7.4.5' "$BOOTSTRAP_WF" \
  && grep -q -- '--set DOCKER_IMAGE_SMTP=mirror.gcr.io/devture/exim-relay:4.96-r1-0' "$BOOTSTRAP_WF"; then
  pass "workflow uses public mirror.gcr.io image refs for CI bootstrap dependency acquisition"
else
  fail "workflow missing public mirror.gcr.io image refs for CI bootstrap dependency acquisition"
fi

if grep -q 'DOCKER_COMPOSE_VERSION:' "$BOOTSTRAP_WF" \
  && grep -q 'Ensure Docker Compose CLI' "$BOOTSTRAP_WF" \
  && grep -q './scripts/ci/install-docker-compose.sh' "$BOOTSTRAP_WF" \
  && grep -q 'docker-compose-linux-\${compose_arch}' "$COMPOSE_INSTALLER" \
  && grep -q 'sha256sum -c "\$asset.sha256"' "$COMPOSE_INSTALLER" \
  && grep -q 'docker compose version' "$COMPOSE_INSTALLER"; then
  pass "workflow bootstraps Docker Compose CLI through checksum-verified helper"
else
  fail "workflow missing Docker Compose CLI helper/checksum bootstrap contract"
fi

if grep -q 'docker compose version' "$BOOTSTRAP_WF" \
  && grep -q 'command -v docker-compose' "$BOOTSTRAP_WF" \
  && grep -q 'compose "\${COMPOSE_ARGS\[@\]}" config --images' "$BOOTSTRAP_WF" \
  && grep -q 'expected-compose-images.txt' "$BOOTSTRAP_WF"; then
  pass "workflow resolves rendered local Compose image set before launch with v2/v1 fallback"
else
  fail "workflow missing rendered local Compose image resolution with v2/v1 fallback"
fi

if grep -q 'pull_with_retry()' "$BOOTSTRAP_WF" \
  && grep -q 'timeout 20m docker pull "\$image_ref"' "$BOOTSTRAP_WF" \
  && grep -q 'docker pull failed after' "$BOOTSTRAP_WF" \
  && grep -q 'pull_with_retry "\$image_ref"' "$BOOTSTRAP_WF" \
  && grep -q 'pulled-image-ids.txt' "$BOOTSTRAP_WF"; then
  pass "workflow refreshes rendered bootstrap images with bounded retry and records pulled image IDs"
else
  fail "workflow missing rendered bootstrap image refresh retry/provenance contract"
fi

if grep -q 'tutor local launch -I --skip-build' "$BOOTSTRAP_WF" \
  && ! grep -Eq 'timeout[[:space:]]+[0-9]+[mh]?[[:space:]]+tutor local launch -I --skip-build' "$BOOTSTRAP_WF"; then
  pass "workflow launches local Tutor baseline without local image builds and relies on job timeout budget"
else
  fail "workflow missing canonical skip-build launch contract"
fi

if grep -q 'actual-running-images.txt' "$BOOTSTRAP_WF" \
  && grep -q 'bootstrap-image-provenance-check.txt' "$BOOTSTRAP_WF"; then
  pass "workflow validates running tutor_local images against pulled provenance"
else
  fail "workflow missing bootstrap image provenance validation"
fi

if grep -q 'config\.redacted\.yml' "$BOOTSTRAP_WF" \
  && grep -Fq 'line.strip() == ""' "$BOOTSTRAP_WF" \
  && grep -q 'secret_key = re.compile' "$BOOTSTRAP_WF"; then
  pass "workflow redacts scalar and multi-line Tutor config secrets before artifact upload"
else
  fail "workflow missing multi-line Tutor config secret redaction contract"
fi

if grep -q './scripts/infra/verify-local-bootstrap-readiness.sh' "$BOOTSTRAP_WF"; then
  pass "workflow runs bootstrap readiness verifier after provenance gate"
else
  fail "workflow missing bootstrap readiness verifier invocation"
fi

if grep -Fq 'if: ${{ always() }}' "$BOOTSTRAP_WF" \
  && grep -q 'actions/upload-artifact' "$BOOTSTRAP_WF" \
  && grep -q 'tutor local down -v' "$BOOTSTRAP_WF"; then
  pass "workflow always captures artifacts and always cleans up local Tutor containers"
else
  fail "workflow missing always-on artifact or cleanup contract"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
