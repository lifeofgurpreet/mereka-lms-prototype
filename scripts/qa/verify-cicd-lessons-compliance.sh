#!/usr/bin/env bash
# @covers AC-CICD-LESSONS-001, AC-CICD-LESSONS-002, AC-CICD-LESSONS-003, AC-CICD-LESSONS-004
# @spec: ci-cd-pipeline_spec.md
#
# verify-cicd-lessons-compliance.sh
#
# Verifies that the eight CI/CD build pipeline lessons (ADR-026) are being
# followed. Each check corresponds to a binding decision from the ADR.
#
# Binding decisions checked:
#   B1 — No GAR registry refs in workflow files (registry matches deployment target)
#   B6 — Tutor version in requirements-tutor.txt matches any version pins in workflows
#   B7 — No hard-coded python3.11 paths in CI/workflow/Dockerfile files (Ulmo uses 3.12)
#   B8 — DinD MTU config present in ARC heavy runner manifests
#
# Exits 0 on PASS, non-zero on any FAIL.
#
# Usage:
#   scripts/qa/verify-cicd-lessons-compliance.sh
#   VERBOSE=1 scripts/qa/verify-cicd-lessons-compliance.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERBOSE="${VERBOSE:-0}"

PASS=0
FAIL=0

# ── helpers ──────────────────────────────────────────────────────────────────

pass() {
  echo "  PASS  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL  $1"
  FAIL=$((FAIL + 1))
}

verbose() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo "        $1"
  fi
}

# ── B1: No GCP Artifact Registry references in workflow files ─────────────────
# Lesson 1: Registry must match deployment target. GAR requires GCP credentials
# not available on rke2-nonprod. Default to GHCR for all new images.
echo ""
echo "── B1: No GAR registry references in workflow files ─────────────────────"

GAR_PATTERN="asia-southeast1-docker\.pkg\.dev"
WORKFLOW_DIR="${REPO_ROOT}/.github/workflows"

if [[ ! -d "$WORKFLOW_DIR" ]]; then
  fail "B1: .github/workflows directory not found at ${WORKFLOW_DIR}"
else
  gar_hits=()
  while IFS= read -r line; do
    gar_hits+=("$line")
  done < <(grep -r "$GAR_PATTERN" "$WORKFLOW_DIR" --include="*.yml" --include="*.yaml" -l 2>/dev/null || true)

  if [[ ${#gar_hits[@]} -eq 0 ]]; then
    pass "B1: No GAR registry references found in workflow files"
  else
    fail "B1: GAR registry references found in workflow files (use GHCR instead):"
    for f in "${gar_hits[@]}"; do
      verbose "  -> $f"
      echo "        $f"
    done
  fi
fi

# Also check composite actions
ACTIONS_DIR="${REPO_ROOT}/.github/actions"
if [[ -d "$ACTIONS_DIR" ]]; then
  gar_action_hits=()
  while IFS= read -r line; do
    gar_action_hits+=("$line")
  done < <(grep -r "$GAR_PATTERN" "$ACTIONS_DIR" --include="*.yml" --include="*.yaml" -l 2>/dev/null || true)

  if [[ ${#gar_action_hits[@]} -eq 0 ]]; then
    pass "B1: No GAR registry references found in composite action files"
  else
    fail "B1: GAR registry references found in composite action files:"
    for f in "${gar_action_hits[@]}"; do
      echo "        $f"
    done
  fi
fi

# ── B6: Tutor version consistency ─────────────────────────────────────────────
# Lesson 6: requirements-tutor.txt is the single source of truth for Tutor versions.
# Any version pin in workflow files must match the requirements-tutor.txt pin.
echo ""
echo "── B6: Tutor version consistency (requirements-tutor.txt is source of truth) ──"

REQUIREMENTS_FILE="${REPO_ROOT}/requirements-tutor.txt"

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  fail "B6: requirements-tutor.txt not found at ${REQUIREMENTS_FILE}"
else
  # Extract the pinned tutor version from requirements-tutor.txt.
  tutor_version=""
  tutor_version=$(grep -E '^tutor(\[full\])?==' "$REQUIREMENTS_FILE" 2>/dev/null | \
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

  if [[ -z "$tutor_version" ]]; then
    fail "B6: Could not extract Tutor version from ${REQUIREMENTS_FILE}"
  else
    verbose "Detected Tutor version: ${tutor_version}"
    pass "B6: Tutor version extracted from requirements-tutor.txt: ${tutor_version}"

    # Check for workflow files referencing a DIFFERENT tutor version
    # We only flag explicit version pins (tutor==X.Y.Z or tutor[full]==X.Y.Z),
    # not environment variable references or comments.
    mismatch_hits=()
    while IFS= read -r match; do
      # Extract just the version number from the match
      found_ver=$(echo "$match" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
      if [[ -n "$found_ver" && "$found_ver" != "$tutor_version" ]]; then
        mismatch_hits+=("$match")
      fi
    done < <(grep -rnE "tutor(\\[full\\])?==[0-9]" \
      "${REPO_ROOT}/.github" \
      --include="*.yml" --include="*.yaml" --include="*.sh" \
      2>/dev/null || true)

    if [[ ${#mismatch_hits[@]} -eq 0 ]]; then
      pass "B6: No mismatched Tutor version pins found in workflow files"
    else
      fail "B6: Workflow files reference a different Tutor version than requirements-tutor.txt (${tutor_version}):"
      for m in "${mismatch_hits[@]}"; do
        echo "        $m"
      done
    fi
  fi
fi

# ── B7: No hard-coded python3.11 in CI/Dockerfile/workflow files ─────────────
# Lesson 7: Tutor Ulmo (21.x) uses Python 3.12. Hard-coded python3.11 references
# fail inside the container with "command not found".
echo ""
echo "── B7: No hard-coded python3.11 in CI/Dockerfile/workflow files ────────"

py311_hits=()
while IFS= read -r match; do
  [[ -n "$match" ]] && py311_hits+=("$match")
done < <(python3 - "$REPO_ROOT" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
check_dirs = (
    repo_root / ".github",
    repo_root / "scripts",
    repo_root / "infrastructure" / "tutor",
)
exempt_patterns = (
    "docs/adr/historical/026-cicd-build-pipeline-lessons.md",
    "verify-cicd-lessons-compliance.sh",
)
include_suffixes = {".sh", ".yml", ".yaml"}
token_pattern = re.compile(r"(?<![/\\\w.-])python3\.11(?![/\\\w.-])")

for root in check_dirs:
    if not root.exists():
        continue
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if not (
            path.suffix in include_suffixes
            or path.name == "Dockerfile"
            or path.name.startswith("Dockerfile.")
        ):
            continue
        rel = path.relative_to(repo_root).as_posix()
        if any(pattern in rel for pattern in exempt_patterns):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if token_pattern.search(line):
                print(f"{path}:{lineno}:{line}")
PY
)

if [[ ${#py311_hits[@]} -eq 0 ]]; then
  pass "B7: No hard-coded python3.11 references found in CI/Dockerfile/workflow files"
else
  fail "B7: Hard-coded python3.11 found (Ulmo uses python3.12; use 'python3' in containers):"
  for h in "${py311_hits[@]}"; do
    echo "        $h"
  done
fi

# ── B8: DinD MTU config present in ARC heavy runner manifests ────────────────
# Lesson 8: rke2-nonprod uses Calico+WireGuard (MTU 1280). Docker's default
# bridge MTU (1500) causes silent packet drops on large transfers inside DinD.
echo ""
echo "── B8: DinD MTU config present in ARC manifests ────────────────────────"

ARC_BASE="${REPO_ROOT}/deploy/k8s/base/arc"
DIND_CONFIG="${ARC_BASE}/dind-daemon-config.yaml"
HEAVY_RUNNER="${ARC_BASE}/runner-scale-set-heavy.yaml"

if [[ ! -f "$DIND_CONFIG" ]]; then
  fail "B8: DinD daemon config not found at ${DIND_CONFIG}"
else
  # Check that daemon.json contains an mtu key
  if grep -q '"mtu"' "$DIND_CONFIG" 2>/dev/null; then
    mtu_val=$(grep '"mtu"' "$DIND_CONFIG" | grep -oE '[0-9]+' | head -1 || true)
    pass "B8: DinD daemon.json present with MTU=${mtu_val} in ${DIND_CONFIG}"
  else
    fail "B8: DinD daemon.json found but missing \"mtu\" key in ${DIND_CONFIG}"
  fi
fi

if [[ ! -f "$HEAVY_RUNNER" ]]; then
  fail "B8: Heavy runner manifest not found at ${HEAVY_RUNNER}"
else
  # Check that the heavy runner passes --mtu to dockerd
  if grep -q -- "--mtu=" "$HEAVY_RUNNER" 2>/dev/null; then
    runner_mtu=$(grep -- "--mtu=" "$HEAVY_RUNNER" | grep -oE '[0-9]+' | head -1 || true)
    pass "B8: Heavy runner DinD sidecar passes --mtu=${runner_mtu} to dockerd"
  else
    fail "B8: Heavy runner manifest does not pass --mtu to dockerd in DinD args (${HEAVY_RUNNER})"
  fi
fi

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
echo "  Results: ${PASS}/${TOTAL} checks passed"

if [[ "$FAIL" -gt 0 ]]; then
  echo "  FAIL — ${FAIL} check(s) failed. See ADR-026 for remediation guidance."
  echo "         docs/adr/historical/026-cicd-build-pipeline-lessons.md"
  exit 1
else
  echo "  PASS — All CI/CD lessons compliance checks passed."
  exit 0
fi
