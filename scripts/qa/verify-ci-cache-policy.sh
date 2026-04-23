#!/usr/bin/env bash
# @covers AC-BAUTH-005, AC-BAUTH-010
# @spec: build-authority-deterministic-builds_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

json_get() {
  local json="$1"
  local path="$2"
  JSON_DOC="$json" python3 - "$path" <<'PY'
import json
import os
import re
import sys

node = json.loads(os.environ["JSON_DOC"])
for part in sys.argv[1].split("."):
    match = re.fullmatch(r"([^.[]+)(?:\[(\d+)\])?", part)
    if match is None:
        raise SystemExit(f"unsupported path segment: {part}")
    key = match.group(1)
    index = match.group(2)
    node = node[key]
    if index is not None:
        node = node[int(index)]
if isinstance(node, (dict, list)):
    print(json.dumps(node, sort_keys=True))
else:
    print(node)
PY
}

check_bake_scalar() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(json_get "$json" "$path")"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_bake_label() {
  local json="$1"
  local target="$2"
  local key="$3"
  local expected="$4"
  local label="$5"
  local actual
  actual="$(JSON_DOC="$json" TARGET_NAME="$target" LABEL_KEY="$key" python3 - <<'PY'
import json
import os

document = json.loads(os.environ["JSON_DOC"])
print(document["target"][os.environ["TARGET_NAME"]]["labels"][os.environ["LABEL_KEY"]])
PY
)"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_bake_list_contains() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local label="$4"
  if JSON_DOC="$json" TARGET_PATH="$path" EXPECTED_VALUE="$expected" python3 - <<'PY'
import json
import os
import re

node = json.loads(os.environ["JSON_DOC"])
for part in os.environ["TARGET_PATH"].split("."):
    match = re.fullmatch(r"([^.[]+)(?:\[(\d+)\])?", part)
    if match is None:
        raise SystemExit(2)
    key = match.group(1)
    index = match.group(2)
    node = node[key]
    if index is not None:
        node = node[int(index)]
if os.environ["EXPECTED_VALUE"] not in node:
    raise SystemExit(1)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

check_bake_object_array_contains() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local label="$4"
  if JSON_DOC="$json" TARGET_PATH="$path" EXPECTED_SPEC="$expected" python3 - <<'PY'
import json
import os
import re
import sys

node = json.loads(os.environ["JSON_DOC"])
for part in os.environ["TARGET_PATH"].split("."):
    match = re.fullmatch(r"([^.[]+)(?:\[(\d+)\])?", part)
    if match is None:
        raise SystemExit(2)
    key = match.group(1)
    index = match.group(2)
    node = node[key]
    if index is not None:
        node = node[int(index)]

expected = {}
for raw_item in os.environ["EXPECTED_SPEC"].split(","):
    item = raw_item.strip()
    if not item:
        continue
    if "=" not in item:
        sys.stderr.write(f"unsupported expected spec fragment: {item}\n")
        raise SystemExit(2)
    key, value = item.split("=", 1)
    expected[key] = value

for entry in node:
    if isinstance(entry, str):
        normalized_entry = {}
        for raw_item in entry.split(","):
            item = raw_item.strip()
            if not item or "=" not in item:
                continue
            key, value = item.split("=", 1)
            normalized_entry[key] = value
        entry = normalized_entry
    if isinstance(entry, dict) and all(str(entry.get(key)) == value for key, value in expected.items()):
        raise SystemExit(0)

raise SystemExit(1)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

bake_print() {
  local target="$1"
  shift
  env "$@" docker buildx bake -f "$REPO_ROOT/docker-bake.hcl" --push --print "$target"
}

NODE_ACTION="$REPO_ROOT/.github/actions/setup-playwright/action.yml"
PYTHON_ACTION="$REPO_ROOT/.github/actions/setup-python-playwright/action.yml"
SMOKE_UNAUTHENTICATED="$REPO_ROOT/.github/workflows/smoke-unauthenticated.yml"
SMOKE_AUTHENTICATED="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"
OPERATIONS_GATES="$REPO_ROOT/.github/workflows/operations-gates-runtime.yml"
POST_DEPLOY_E2E="$REPO_ROOT/.github/workflows/post-deploy-e2e.yml"
E2E_TESTS="$REPO_ROOT/.github/workflows/e2e-tests.yml"
OPENEDX_BUILD="$REPO_ROOT/scripts/infra/build-openedx-image.sh"
MFE_BUILD="$REPO_ROOT/scripts/infra/build-mfe-image.sh"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"

echo -e "${BLUE}=== CI Cache Policy Verification ===${NC}"
echo

echo -e "${BLUE}## Shared Playwright actions${NC}"
check_contains "$NODE_ACTION" "path: ~/.cache/ms-playwright" "setup-playwright caches Playwright browsers"
check_contains "$NODE_ACTION" "npx playwright install chromium" "setup-playwright repairs Chromium on cache miss"
check_contains "$NODE_ACTION" "npm-cache-dependency-path" "setup-playwright supports npm dependency cache keys"

check_contains "$PYTHON_ACTION" "uses: ./.github/actions/setup-python-env" "setup-python-playwright reuses setup-python-env"
check_contains "$PYTHON_ACTION" "path: ~/.cache/ms-playwright" "setup-python-playwright caches Playwright browsers"
check_contains "$PYTHON_ACTION" 'python -m playwright install "${args[@]}"' "setup-python-playwright repairs Chromium on cache miss"
check_contains "$PYTHON_ACTION" "install-system-deps" "setup-python-playwright supports system dependency installation"
echo

echo -e "${BLUE}## Browser workflow bootstrap paths${NC}"
check_contains "$SMOKE_UNAUTHENTICATED" "uses: ./.github/actions/setup-playwright" "smoke-unauthenticated uses shared Node Playwright action"
check_contains "$SMOKE_UNAUTHENTICATED" "npm-cache-dependency-path: tests/e2e/package-lock.json" "smoke-unauthenticated keys npm cache from tests/e2e lockfile"
check_absent "$SMOKE_UNAUTHENTICATED" "npx playwright install --with-deps chromium" "smoke-unauthenticated does not install browsers inline"

check_contains "$SMOKE_AUTHENTICATED" "uses: ./.github/actions/setup-playwright" "smoke-authenticated smoke job uses shared Node Playwright action"
check_contains "$SMOKE_AUTHENTICATED" "uses: ./.github/actions/setup-python-playwright" "smoke-authenticated sso-canary job uses shared Python Playwright action"
check_absent "$SMOKE_AUTHENTICATED" "python -m playwright install chromium" "smoke-authenticated does not install Python Playwright browsers inline"
check_absent "$SMOKE_AUTHENTICATED" "path: ~/.cache/ms-playwright" "smoke-authenticated does not duplicate Playwright cache wiring inline"

check_contains "$OPERATIONS_GATES" "uses: ./.github/actions/setup-python-playwright" "operations-gates-runtime uses shared Python Playwright action"
check_contains "$OPERATIONS_GATES" "install-system-deps: 'true'" "operations-gates-runtime requests system deps through the shared Python Playwright action"
check_absent "$OPERATIONS_GATES" "python -m playwright install --with-deps chromium" "operations-gates-runtime does not install browsers inline"

check_contains "$POST_DEPLOY_E2E" "uses: ./.github/actions/setup-playwright" "post-deploy-e2e uses shared Node Playwright action"
check_contains "$E2E_TESTS" "uses: ./.github/actions/setup-playwright" "e2e-tests uses shared Node Playwright action"
echo

echo -e "${BLUE}## Image build cache policy${NC}"
check_contains "$OPENEDX_BUILD" 'docker buildx bake' "build-openedx-image routes execution through buildx bake"
check_contains "$MFE_BUILD" 'docker buildx bake' "build-mfe-image routes execution through buildx bake"
check_contains "$OPENEDX_BUILD" '--local-defaults' "build-openedx-image exposes repo-local front-door defaults"
check_contains "$MFE_BUILD" '--local-defaults' "build-mfe-image exposes repo-local front-door defaults"
check_contains "$OPENEDX_BUILD" '--output-mode <push|docker>' "build-openedx-image documents explicit output mode selection"
check_contains "$MFE_BUILD" '--output-mode <push|docker>' "build-mfe-image documents explicit output mode selection"
check_contains "$OPENEDX_BUILD" '--cache-mode <default|none>' "build-openedx-image documents explicit cache mode selection"
check_contains "$MFE_BUILD" '--cache-mode <default|none>' "build-mfe-image documents explicit cache mode selection"
OPENEDX_PROOF_JSON="$(bake_print openedx-proof \
  "OPENEDX_PROOF_TAGS=example.invalid/openedx:one,example.invalid/openedx:two" \
  "OPENEDX_CACHE_REF=example.invalid/openedx:cache" \
  "OPENEDX_PROOF_GHA_SCOPE=verify-openedx-proof")"
MFE_PROOF_JSON="$(bake_print mfe-proof \
  "MFE_PROOF_TAGS=example.invalid/mfe:one,example.invalid/mfe:two" \
  "MFE_CACHE_REF=example.invalid/mfe:cache" \
  "MFE_PROOF_GHA_SCOPE=verify-mfe-proof")"
OPENEDX_PROOF_NOCACHE_JSON="$(bake_print openedx-proof-nocache \
  "OPENEDX_PROOF_TAGS=example.invalid/openedx:one,example.invalid/openedx:two" \
  "OPENEDX_CACHE_REF=example.invalid/openedx:cache" \
  "OPENEDX_PROOF_GHA_SCOPE=verify-openedx-proof")"
MFE_PROOF_NOCACHE_JSON="$(bake_print mfe-proof-nocache \
  "MFE_PROOF_TAGS=example.invalid/mfe:one,example.invalid/mfe:two" \
  "MFE_CACHE_REF=example.invalid/mfe:cache" \
  "MFE_PROOF_GHA_SCOPE=verify-mfe-proof")"

check_bake_scalar "$OPENEDX_PROOF_JSON" "target.openedx-proof.context" "tutor_env/env/build/openedx" "openedx-proof resolves expected context"
check_bake_scalar "$OPENEDX_PROOF_JSON" "target.openedx-proof.dockerfile" "Dockerfile" "openedx-proof resolves expected dockerfile"
check_bake_label "$OPENEDX_PROOF_JSON" "openedx-proof" "io.mereka.build-profile" "proof" "openedx-proof resolves build-profile label"
check_bake_label "$OPENEDX_PROOF_JSON" "openedx-proof" "io.mereka.build-scope" "openedx" "openedx-proof resolves build-scope label"
check_bake_list_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.tags" "example.invalid/openedx:one" "openedx-proof resolves first image tag"
check_bake_list_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.tags" "example.invalid/openedx:two" "openedx-proof resolves second image tag"
# L2 shared GHCR registry cache (authoritative) — RFC-BUILD-AUTHORITY-001
check_bake_object_array_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.cache-from" "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64" "openedx-proof resolves L2 shared GHCR registry cache"
# L3 final-image fallback (transitional)
check_bake_object_array_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.cache-from" "type=registry,ref=example.invalid/openedx:cache" "openedx-proof resolves L3 registry cache fallback"
# cache-to is variable-driven: when CACHE_TO_OPENEDX="" buildx omits cache-to entirely
# This is correct behavior (PRs don't write shared cache)
if echo "$OPENEDX_PROOF_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'cache-to' not in d['target']['openedx-proof'] else 1)" 2>/dev/null; then
  pass "openedx-proof cache-to absent by default (variable-driven, empty = no export)"
else
  fail "openedx-proof cache-to should be absent when CACHE_TO_OPENEDX is empty"
fi
check_bake_object_array_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.output" "type=docker" "openedx-proof retains docker output"
check_bake_object_array_contains "$OPENEDX_PROOF_JSON" "target.openedx-proof.output" "type=image,push=true" "openedx-proof resolves push image output"
if echo "$OPENEDX_PROOF_NOCACHE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); t=d['target']['openedx-proof-nocache']; sys.exit(0 if 'cache-from' not in t and 'cache-to' not in t else 1)" 2>/dev/null; then
  pass "openedx-proof-nocache omits cache-from/cache-to for app-cache-cold proof"
else
  fail "openedx-proof-nocache must omit cache-from/cache-to for app-cache-cold proof"
fi

check_bake_scalar "$MFE_PROOF_JSON" "target.mfe-proof.context" "tutor_env/env/plugins/mfe/build/mfe" "mfe-proof resolves expected context"
check_bake_scalar "$MFE_PROOF_JSON" "target.mfe-proof.dockerfile" "Dockerfile" "mfe-proof resolves expected dockerfile"
check_bake_label "$MFE_PROOF_JSON" "mfe-proof" "io.mereka.build-profile" "proof" "mfe-proof resolves build-profile label"
check_bake_label "$MFE_PROOF_JSON" "mfe-proof" "io.mereka.build-scope" "mfe" "mfe-proof resolves build-scope label"
check_bake_label "$MFE_PROOF_JSON" "mfe-proof" "io.mereka.rendered-context" "tutor_env/env/plugins/mfe/build/mfe" "mfe-proof resolves rendered-context label"
check_bake_label "$MFE_PROOF_JSON" "mfe-proof" "io.mereka.rendered-dockerfile" "Dockerfile" "mfe-proof resolves rendered-dockerfile label"
check_bake_list_contains "$MFE_PROOF_JSON" "target.mfe-proof.tags" "example.invalid/mfe:one" "mfe-proof resolves first image tag"
check_bake_list_contains "$MFE_PROOF_JSON" "target.mfe-proof.tags" "example.invalid/mfe:two" "mfe-proof resolves second image tag"
# L2 shared GHCR registry cache (authoritative) — RFC-BUILD-AUTHORITY-001
check_bake_object_array_contains "$MFE_PROOF_JSON" "target.mfe-proof.cache-from" "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64" "mfe-proof resolves L2 shared GHCR registry cache"
# L3 final-image fallback (transitional)
check_bake_object_array_contains "$MFE_PROOF_JSON" "target.mfe-proof.cache-from" "type=registry,ref=example.invalid/mfe:cache" "mfe-proof resolves L3 registry cache fallback"
# cache-to is variable-driven: when CACHE_TO_MFE="" buildx omits cache-to entirely
if echo "$MFE_PROOF_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'cache-to' not in d['target']['mfe-proof'] else 1)" 2>/dev/null; then
  pass "mfe-proof cache-to absent by default (variable-driven, empty = no export)"
else
  fail "mfe-proof cache-to should be absent when CACHE_TO_MFE is empty"
fi
check_bake_object_array_contains "$MFE_PROOF_JSON" "target.mfe-proof.output" "type=docker" "mfe-proof retains docker output"
check_bake_object_array_contains "$MFE_PROOF_JSON" "target.mfe-proof.output" "type=image,push=true" "mfe-proof resolves push image output"
if echo "$MFE_PROOF_NOCACHE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); t=d['target']['mfe-proof-nocache']; sys.exit(0 if 'cache-from' not in t and 'cache-to' not in t else 1)" 2>/dev/null; then
  pass "mfe-proof-nocache omits cache-from/cache-to for app-cache-cold proof"
else
  fail "mfe-proof-nocache must omit cache-from/cache-to for app-cache-cold proof"
fi

check_contains "$BUILD_WORKFLOW" "uses: docker/setup-buildx-action" "build-tutor-images uses buildx"
check_contains "$BUILD_WORKFLOW" "./scripts/infra/build-openedx-image.sh" "build-tutor-images routes OpenEdX through the cache-aware helper"
check_contains "$BUILD_WORKFLOW" "./scripts/infra/build-mfe-image.sh" "build-tutor-images routes MFE through the cache-aware helper"
echo

echo -e "${BLUE}## Summary${NC}"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

echo "CI cache policy checks passed."
