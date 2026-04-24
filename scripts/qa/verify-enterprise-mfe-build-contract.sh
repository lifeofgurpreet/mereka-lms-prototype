#!/usr/bin/env bash
# verify-enterprise-mfe-build-contract.sh
#
# CI-safe static verifier for the Enterprise MFE build contract.
# Ensures Dockerfiles, workflows, and build inputs follow the build truth
# separation contract (source truth / cache truth / release truth).
#
# @covers AC-BUILD-001, AC-BUILD-002, AC-BUILD-003, AC-BUILD-004
# @spec: k8s-deployment
#
# Exit 0 = contract holds
# Exit 1 = contract violation found
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "=== Enterprise MFE Build Contract Verification ==="
echo ""

# ──────────────────────────────────────────────────────────────
# 1. Dockerfiles must NOT default SOURCE_TAG to "latest"
# ──────────────────────────────────────────────────────────────
echo "[1] Dockerfile source tag defaults"

DOCKERFILES=(
  "infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal"
  "infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal"
)

for df in "${DOCKERFILES[@]}"; do
  filepath="${REPO_ROOT}/${df}"
  if [[ ! -f "${filepath}" ]]; then
    fail "${df}: file not found"
    continue
  fi

  # Check for unsafe default: ARG SOURCE_TAG=latest
  if grep -qE '^\s*ARG\s+SOURCE_TAG\s*=\s*latest\s*$' "${filepath}"; then
    fail "${df}: SOURCE_TAG defaults to 'latest' — must require explicit tag"
  else
    pass "${df}: SOURCE_TAG does not default to 'latest'"
  fi

  # Check that FROM uses SOURCE_TAG (not hardcoded :latest)
  if grep -qE '^\s*FROM\s+.*:latest\s*$' "${filepath}"; then
    fail "${df}: FROM hardcodes ':latest' — must use \${SOURCE_TAG}"
  else
    pass "${df}: FROM does not hardcode ':latest'"
  fi

  # Check that SOURCE_TAG is used in FROM
  if grep -qE '^\s*FROM\s+.*\$\{?SOURCE_TAG' "${filepath}"; then
    pass "${df}: FROM references SOURCE_TAG variable"
  else
    fail "${df}: FROM does not reference SOURCE_TAG — source ref is not parameterized"
  fi
done

echo ""

# ──────────────────────────────────────────────────────────────
# 2. Workflow must pass explicit SOURCE_TAG via build_args
# ──────────────────────────────────────────────────────────────
echo "[2] Workflow source tag passthrough"

WORKFLOW="${REPO_ROOT}/.github/workflows/build-enterprise-mfe.yml"

if [[ ! -f "${WORKFLOW}" ]]; then
  fail "build-enterprise-mfe.yml: not found"
else
  # Check that build_args with SOURCE_TAG is passed
  if grep -qE 'build_args:' "${WORKFLOW}" && grep -qE 'SOURCE_TAG=' "${WORKFLOW}"; then
    pass "build-enterprise-mfe.yml: passes SOURCE_TAG via build_args"
  else
    fail "build-enterprise-mfe.yml: does not pass SOURCE_TAG via build_args"
  fi

  # Check that there's a resolve step
  if grep -qE 'resolve.*source|resolve.*tag' "${WORKFLOW}"; then
    pass "build-enterprise-mfe.yml: has source tag resolution step"
  else
    fail "build-enterprise-mfe.yml: no source tag resolution step found"
  fi
fi

echo ""

# ──────────────────────────────────────────────────────────────
# 3. Output tags must be immutable (SHA-based, not just :latest)
# ──────────────────────────────────────────────────────────────
echo "[3] Immutable output tags"

# The reusable workflow produces SHA-TIMESTAMP tags — verify the caller
# references a workflow that generates immutable tags (we check outputs)
if [[ -f "${WORKFLOW}" ]]; then
  if grep -qE 'GITHUB_SHA|image_tag|tag=' "${WORKFLOW}"; then
    pass "build-enterprise-mfe.yml: references SHA-based tag generation"
  else
    warn "build-enterprise-mfe.yml: could not confirm immutable output tag pattern"
  fi
fi

echo ""

# ──────────────────────────────────────────────────────────────
# 4. Cache and source must be separate concerns
# ──────────────────────────────────────────────────────────────
echo "[4] Cache/source separation"

for df in "${DOCKERFILES[@]}"; do
  filepath="${REPO_ROOT}/${df}"
  [[ ! -f "${filepath}" ]] && continue

  # Ensure no cache-related directives in Dockerfile (cache is a workflow concern)
  if grep -qiE '^\s*#.*cache|BUILDKIT_INLINE_CACHE' "${filepath}"; then
    warn "${df}: has cache-related comments/directives in Dockerfile (cache should be workflow-only)"
  else
    pass "${df}: no cache directives in Dockerfile (cache is workflow concern)"
  fi
done

echo ""

# ──────────────────────────────────────────────────────────────
# 5. No workflow_dispatch without explicit source option
# ──────────────────────────────────────────────────────────────
echo "[5] Manual dispatch safety"

if [[ -f "${WORKFLOW}" ]]; then
  if grep -qE 'workflow_dispatch:' "${WORKFLOW}"; then
    if grep -qE 'source_tag:' "${WORKFLOW}"; then
      pass "build-enterprise-mfe.yml: workflow_dispatch has source_tag input"
    else
      warn "build-enterprise-mfe.yml: workflow_dispatch exists but no source_tag input"
    fi
  fi
fi

echo ""

# ──────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo "  WARN: ${WARN}"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo "BUILD CONTRACT VIOLATION — ${FAIL} failure(s) found"
  exit 1
fi

echo ""
echo "BUILD CONTRACT HOLDS"
exit 0
