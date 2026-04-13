#!/usr/bin/env bash
# @covers AC-CI-BOOTSTRAP-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify bootstrap-local-readiness.yml contract:
#   - workflow exists and is serialized on persistent self-hosted runners
#   - canonical Tutor config and bootstrap-readiness front doors are used
#   - rendered local Compose images are resolved and pulled before launch
#   - provenance is checked against actual running tutor_local container images
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BOOTSTRAP_WF="${BOOTSTRAP_WF_OVERRIDE:-$REPO_ROOT/.github/workflows/bootstrap-local-readiness.yml}"
CONFIG_FRONT_DOOR="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
READINESS_SCRIPT="$REPO_ROOT/scripts/infra/verify-local-bootstrap-readiness.sh"

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

if grep -q 'runs-on: mereka-k8s-heavy-builders' "$BOOTSTRAP_WF"; then
  pass "workflow uses heavy-builders for local bootstrap"
else
  fail "workflow missing heavy-builder runner contract"
fi

if grep -q './scripts/infra/tutor-config-save.sh' "$BOOTSTRAP_WF"; then
  pass "workflow renders config through canonical tutor-config-save front door"
else
  fail "workflow missing canonical tutor-config-save invocation"
fi

if grep -q 'docker compose "\${COMPOSE_ARGS\[@\]}" config --images' "$BOOTSTRAP_WF" \
  && grep -q 'expected-compose-images.txt' "$BOOTSTRAP_WF"; then
  pass "workflow resolves rendered local Compose image set before launch"
else
  fail "workflow missing rendered local Compose image resolution"
fi

if grep -q 'timeout 20m docker pull "\$image_ref"' "$BOOTSTRAP_WF" \
  && grep -q 'pulled-image-ids.txt' "$BOOTSTRAP_WF"; then
  pass "workflow refreshes rendered bootstrap images and records pulled image IDs"
else
  fail "workflow missing rendered bootstrap image refresh contract"
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
