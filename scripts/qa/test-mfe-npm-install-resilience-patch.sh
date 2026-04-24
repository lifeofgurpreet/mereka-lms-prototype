#!/usr/bin/env bash
# test-mfe-npm-install-resilience-patch.sh - fixture tests for MFE npm patch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH="$REPO_ROOT/infrastructure/tutor/patches/mfe-npm-install-resilience.sh"
TMP_DIR="$(mktemp -d -t mfe-npm-resilience-test.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1" >&2; FAIL=$((FAIL + 1)); }

run_patch() {
  local tutor_root="$1"
  REPO_ROOT="$REPO_ROOT" TUTOR_ROOT="$tutor_root" PYTHON_BIN="${PYTHON_BIN:-python3}" bash -c \
    "source '$PATCH'; apply_mfe_npm_install_resilience_patch"
}

fixture_root="$TMP_DIR/happy/tutor_env"
dockerfile="$fixture_root/env/plugins/mfe/build/mfe/Dockerfile"
mkdir -p "$(dirname "$dockerfile")"
cat >"$dockerfile" <<'EOF'
FROM node:24
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY
RUN echo done
EOF

expected="$TMP_DIR/expected.Dockerfile"
cat >"$expected" <<'EOF'
FROM node:24
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
RUN echo done
EOF

if run_patch "$fixture_root" >/tmp/mfe-npm-resilience.out 2>/tmp/mfe-npm-resilience.err \
  && diff -u "$expected" "$dockerfile"; then
  pass "golden Dockerfile transformation matches expected resilience layer"
else
  cat /tmp/mfe-npm-resilience.err >&2 || true
  fail "golden Dockerfile transformation matches expected resilience layer"
fi

cp "$dockerfile" "$TMP_DIR/after-first.Dockerfile"
if run_patch "$fixture_root" >/tmp/mfe-npm-resilience-idempotent.out 2>/tmp/mfe-npm-resilience-idempotent.err \
  && diff -u "$TMP_DIR/after-first.Dockerfile" "$dockerfile"; then
  pass "patch is idempotent on already patched Dockerfile"
else
  cat /tmp/mfe-npm-resilience-idempotent.err >&2 || true
  fail "patch is idempotent on already patched Dockerfile"
fi

negative_root="$TMP_DIR/negative/tutor_env"
negative_dockerfile="$negative_root/env/plugins/mfe/build/mfe/Dockerfile"
mkdir -p "$(dirname "$negative_dockerfile")"
cat >"$negative_dockerfile" <<'EOF'
FROM node:24
RUN npm ci
EOF

set +e
run_patch "$negative_root" >/tmp/mfe-npm-resilience-negative.out 2>/tmp/mfe-npm-resilience-negative.err
negative_rc=$?
set -e

if [[ "$negative_rc" -ne 0 ]] \
  && grep -q "Upstream MFE Dockerfile changed; resilience patch selector no longer matches" /tmp/mfe-npm-resilience-negative.err; then
  pass "patch fails loudly when upstream npm install selector changes"
else
  cat /tmp/mfe-npm-resilience-negative.out >&2 || true
  cat /tmp/mfe-npm-resilience-negative.err >&2 || true
  fail "patch fails loudly when upstream npm install selector changes"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
