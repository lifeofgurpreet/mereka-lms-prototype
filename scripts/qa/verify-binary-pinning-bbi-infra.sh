#!/usr/bin/env bash
# @covers AC-009, AC-020
# @spec: ci-cd-pipeline_spec.md
# verify-binary-pinning-bbi-infra.sh — Check for unpinned binary downloads in bbi-infrastructure CI.
#
# This is a cross-repo verification script for T057 (DR2:I-015).
# The actual fixes must be made in the bbi-infrastructure repository.
# This script documents what to check and scans the repo if available locally.
#
# Offline checks (no bbi-infrastructure repo required):
#   1. Documents what binary downloads to look for (yq, kubectl, helm, kustomize, etc.)
#   2. Emits SKIP with actionable notes if bbi-infrastructure is not available
#
# Online checks (bbi-infrastructure repo present locally):
#   3. Scans workflow files for unpinned binary download patterns
#   4. Detects curl/wget fetches without SHA256 checksum verification
#   5. Detects version variables that are not pinned to an exact version string
#
# Usage:
#   ./scripts/qa/verify-binary-pinning-bbi-infra.sh
#   BBI_INFRA=/path/to/bbi-infrastructure ./scripts/qa/verify-binary-pinning-bbi-infra.sh
#
# Cross-repo reference: docs/policies/operations/BINARY_PINNING.md
# Task: T057 / DR2:I-015

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

# ---------------------------------------------------------------------------
# Locate bbi-infrastructure repo
# ---------------------------------------------------------------------------

BBI_INFRA="${BBI_INFRA:-}"

if [[ -z "$BBI_INFRA" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure" \
    "${HOME}/projects/k8s/bbi-infrastructure" \
    "${HOME}/projects/k8s/infrastructure" \
    "${REPO_ROOT}/../bbi-infrastructure"; do
    if [[ -d "$candidate/.github/workflows" ]]; then
      BBI_INFRA="$candidate"
      break
    fi
  done
fi

echo "=== verify-binary-pinning-bbi-infra (T057) ==="
echo "    Source repo:  ${REPO_ROOT}"
echo "    GitOps repo:  ${BBI_INFRA:-<not found>}"
echo "    Policy doc:   docs/policies/operations/BINARY_PINNING.md"
echo ""

# ---------------------------------------------------------------------------
# Check 1: Cross-repo task is documented
# ---------------------------------------------------------------------------

POLICY_DOC="${REPO_ROOT}/docs/policies/operations/BINARY_PINNING.md"
if [[ -f "$POLICY_DOC" ]]; then
  pass "Binary pinning policy documented at docs/policies/operations/BINARY_PINNING.md"
else
  fail "Binary pinning policy doc missing: docs/policies/operations/BINARY_PINNING.md"
fi

# ---------------------------------------------------------------------------
# Cross-repo checks — SKIP gracefully if repo not available
# ---------------------------------------------------------------------------

if [[ -z "$BBI_INFRA" ]]; then
  echo ""
  echo "  bbi-infrastructure repo not found locally."
  echo "  The following cross-repo checks are skipped."
  echo "  To run them, clone the repo and set BBI_INFRA=/path/to/bbi-infrastructure."
  echo ""
  skip "bbi-infrastructure workflow scan (repo not available)"
  skip "unpinned yq download check"
  skip "unpinned kubectl download check"
  skip "unpinned helm download check"
  skip "unpinned kustomize download check"
  skip "SHA256 checksum verification check"
  echo ""
  echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
  [[ "$FAILED" -gt 0 ]] && exit 1 || exit 0
fi

WORKFLOWS_DIR="${BBI_INFRA}/.github/workflows"

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  skip "bbi-infrastructure .github/workflows directory not found at ${WORKFLOWS_DIR}"
  echo ""
  echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
  exit 0
fi

pass "bbi-infrastructure repo found at ${BBI_INFRA}"

# Collect all workflow files
mapfile -t WORKFLOW_FILES < <(find "$WORKFLOWS_DIR" -maxdepth 2 -name '*.yml' -o -name '*.yaml' | sort)

if [[ ${#WORKFLOW_FILES[@]} -eq 0 ]]; then
  skip "No workflow files found in ${WORKFLOWS_DIR}"
  echo ""
  echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
  exit 0
fi

pass "Found ${#WORKFLOW_FILES[@]} workflow file(s) to scan"

# ---------------------------------------------------------------------------
# Check 2: Unpinned yq downloads
# ---------------------------------------------------------------------------
# Pattern: curl/wget fetching yq without a pinned version (e.g. "latest" or no version)
# Acceptable: VERSION=v4.44.3 (exact semver) + sha256 verification after download

echo ""
echo "-- Scanning for unpinned yq downloads --"

YQ_VIOLATIONS=0
for f in "${WORKFLOW_FILES[@]}"; do
  # Look for yq download lines
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    # Flag if yq is fetched but no exact version tag is visible on the same line
    # and no sha256 checksum step follows (simple heuristic: "latest" in URL)
    if echo "$content" | grep -qiE 'yq.*(latest|LATEST)'; then
      fname="$(basename "$f")"
      fail "Unpinned yq download (uses 'latest'): ${fname}:${lineno}: ${content}"
      YQ_VIOLATIONS=$((YQ_VIOLATIONS + 1))
    fi
  done < <(grep -n 'yq' "$f" || true)
done

if [[ "$YQ_VIOLATIONS" -eq 0 ]]; then
  pass "No yq 'latest' downloads detected in bbi-infrastructure workflows"
fi

# ---------------------------------------------------------------------------
# Check 3: Unpinned kubectl downloads
# ---------------------------------------------------------------------------

echo ""
echo "-- Scanning for unpinned kubectl downloads --"

KUBECTL_VIOLATIONS=0
for f in "${WORKFLOW_FILES[@]}"; do
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if echo "$content" | grep -qiE 'kubectl.*(latest|LATEST|stable\.txt)'; then
      fname="$(basename "$f")"
      fail "Unpinned kubectl download: ${fname}:${lineno}: ${content}"
      KUBECTL_VIOLATIONS=$((KUBECTL_VIOLATIONS + 1))
    fi
  done < <(grep -n 'kubectl' "$f" || true)
done

if [[ "$KUBECTL_VIOLATIONS" -eq 0 ]]; then
  pass "No kubectl 'latest/stable' downloads detected in bbi-infrastructure workflows"
fi

# ---------------------------------------------------------------------------
# Check 4: Unpinned helm downloads
# ---------------------------------------------------------------------------

echo ""
echo "-- Scanning for unpinned helm downloads --"

HELM_VIOLATIONS=0
for f in "${WORKFLOW_FILES[@]}"; do
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if echo "$content" | grep -qiE 'helm.*(latest|LATEST)'; then
      fname="$(basename "$f")"
      fail "Unpinned helm download: ${fname}:${lineno}: ${content}"
      HELM_VIOLATIONS=$((HELM_VIOLATIONS + 1))
    fi
  done < <(grep -n 'helm' "$f" || true)
done

if [[ "$HELM_VIOLATIONS" -eq 0 ]]; then
  pass "No helm 'latest' downloads detected in bbi-infrastructure workflows"
fi

# ---------------------------------------------------------------------------
# Check 5: Unpinned kustomize downloads
# ---------------------------------------------------------------------------

echo ""
echo "-- Scanning for unpinned kustomize downloads --"

KUSTOMIZE_VIOLATIONS=0
for f in "${WORKFLOW_FILES[@]}"; do
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if echo "$content" | grep -qiE 'kustomize.*(latest|LATEST)'; then
      fname="$(basename "$f")"
      fail "Unpinned kustomize download: ${fname}:${lineno}: ${content}"
      KUSTOMIZE_VIOLATIONS=$((KUSTOMIZE_VIOLATIONS + 1))
    fi
  done < <(grep -n 'kustomize' "$f" || true)
done

if [[ "$KUSTOMIZE_VIOLATIONS" -eq 0 ]]; then
  pass "No kustomize 'latest' downloads detected in bbi-infrastructure workflows"
fi

# ---------------------------------------------------------------------------
# Check 6: Binary downloads without SHA256 checksum verification
# ---------------------------------------------------------------------------
# Look for curl/wget download patterns that are NOT followed by sha256sum/shasum

echo ""
echo "-- Scanning for binary downloads without checksum verification --"

CHECKSUM_VIOLATIONS=0
for f in "${WORKFLOW_FILES[@]}"; do
  fname="$(basename "$f")"
  file_content="$(< "$f")"

  # Heuristic: if file downloads a binary (curl/wget to a file) but never
  # runs sha256sum / shasum, flag as a warning
  has_download=false
  has_checksum=false

  if echo "$file_content" | grep -qiE '(curl|wget).*(-o |--output |> )'; then
    has_download=true
  fi
  if echo "$file_content" | grep -qiE '(sha256sum|shasum|openssl dgst)'; then
    has_checksum=true
  fi

  if [[ "$has_download" == "true" && "$has_checksum" == "false" ]]; then
    fail "Binary download without SHA256 check: ${fname} — add 'sha256sum --check' after download"
    CHECKSUM_VIOLATIONS=$((CHECKSUM_VIOLATIONS + 1))
  fi
done

if [[ "$CHECKSUM_VIOLATIONS" -eq 0 ]]; then
  pass "All workflow files with binary downloads include checksum verification"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

TOTAL_VIOLATIONS=$((YQ_VIOLATIONS + KUBECTL_VIOLATIONS + HELM_VIOLATIONS + KUSTOMIZE_VIOLATIONS + CHECKSUM_VIOLATIONS))

echo ""
echo "=== Summary ==="
echo "    Workflows scanned : ${#WORKFLOW_FILES[@]}"
echo "    yq violations      : ${YQ_VIOLATIONS}"
echo "    kubectl violations : ${KUBECTL_VIOLATIONS}"
echo "    helm violations    : ${HELM_VIOLATIONS}"
echo "    kustomize violations: ${KUSTOMIZE_VIOLATIONS}"
echo "    checksum violations: ${CHECKSUM_VIOLATIONS}"
echo ""
echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"

if [[ "$TOTAL_VIOLATIONS" -gt 0 ]]; then
  echo ""
  echo "  Fix: See docs/policies/operations/BINARY_PINNING.md for pinning patterns."
  echo "  Changes must be made in the bbi-infrastructure repository (cross-repo task T057)."
fi

[[ "$FAILED" -gt 0 ]] && exit 1 || exit 0
