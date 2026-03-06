#!/usr/bin/env bash
# @covers AC-014
# @spec: ci-cd-pipeline_spec.md
# Verify that the GitOps repo pins `mereka-lms` to the expected commit.
#
# Why:
# - In our GitOps model, production only changes when BBI-K8/bbi-infrastructure
#   bumps the pinned `?ref=<sha>` for the app base.
# - Many "deployment didn't apply" incidents are simply "pinned ref not bumped".
#
# Usage:
#   ./scripts/qa/verify-gitops-mereka-lms-pin.sh
#   ./scripts/qa/verify-gitops-mereka-lms-pin.sh --expected <sha>
#   GITOPS_REPO_ROOT=/path/to/bbi-infrastructure ./scripts/qa/verify-gitops-mereka-lms-pin.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

EXPECTED_SHA=""
GITOPS_REPO_ROOT="${GITOPS_REPO_ROOT:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-gitops-mereka-lms-pin.sh [--expected <sha>]

Env:
  GITOPS_REPO_ROOT   Path to GitOps repo checkout (default auto-detect)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected)
      EXPECTED_SHA="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "${EXPECTED_SHA}" ]]; then
  EXPECTED_SHA="$(cd "$REPO_ROOT" && git rev-parse HEAD)"
fi

if [[ -z "${GITOPS_REPO_ROOT}" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure"; do
    if [[ -d "$candidate/.git" ]]; then
      GITOPS_REPO_ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "${GITOPS_REPO_ROOT}" || ! -d "${GITOPS_REPO_ROOT}/.git" ]]; then
  echo "FAIL: could not locate GitOps repo checkout. Set GITOPS_REPO_ROOT." >&2
  exit 1
fi

PIN_FILE="${GITOPS_REPO_ROOT}/apps/mereka-lms/base/kustomization.yaml"
if [[ ! -f "$PIN_FILE" ]]; then
  echo "FAIL: expected pin file missing: $PIN_FILE" >&2
  exit 1
fi

PINNED_SHA="$(python3 - "$PIN_FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"ref=([0-9a-f]{7,40})", text)
if not m:
    print("")
    raise SystemExit(0)
print(m.group(1))
PY
)"

if [[ -z "${PINNED_SHA}" ]]; then
  echo "FAIL: could not parse pinned ref=... from $PIN_FILE" >&2
  exit 1
fi

if [[ "${PINNED_SHA}" == "${EXPECTED_SHA}" ]]; then
  echo "OK: GitOps pinned ref matches expected SHA"
  echo "  expected: ${EXPECTED_SHA}"
  echo "  pinned:   ${PINNED_SHA}"
  echo "  file:     ${PIN_FILE}"
  exit 0
fi

echo "FAIL: GitOps pinned ref does not match expected SHA" >&2
echo "  expected: ${EXPECTED_SHA}" >&2
echo "  pinned:   ${PINNED_SHA}" >&2
echo "  file:     ${PIN_FILE}" >&2
echo "" >&2
echo "Fix (in GitOps repo): bump apps/mereka-lms/base/kustomization.yaml ref= to ${EXPECTED_SHA}" >&2
exit 1
