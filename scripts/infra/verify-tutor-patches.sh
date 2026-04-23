#!/usr/bin/env bash
# @covers AC-TCR-004
# @spec: tutor-configuration-resilience_spec.md
#
# Legacy compatibility entrypoint. The current rendered verifier is
# scripts/infra/verify-tutor-config.sh, and the static authority contract is
# scripts/qa/verify-tutor-patch-manifest-contract.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ENV="${TUTOR_ROOT:-${REPO_ROOT}/tutor_env}"
MANIFEST_VERIFY="$REPO_ROOT/scripts/qa/verify-tutor-patch-manifest-contract.sh"
RENDERED_VERIFY="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
PREPARE_CONTEXT="$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh"

OUTPUT_MODE="human"
AUTO_FIX=false

usage() {
  cat <<'EOF' >&2
Usage:
  scripts/infra/verify-tutor-patches.sh [--json] [--fix]

This is a legacy compatibility entrypoint.
Use scripts/qa/verify-tutor-patch-manifest-contract.sh for static patch-authority checks.
Use scripts/qa/verify-tutor-patches.sh for the stable rendered verifier entrypoint.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    --fix)
      AUTO_FIX=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$AUTO_FIX" == "true" ]]; then
  "$PREPARE_CONTEXT" --target all
fi

MANIFEST_OUT="$(mktemp -t verify-tutor-patches-manifest.XXXXXX)"
MANIFEST_ERR="$(mktemp -t verify-tutor-patches-manifest-err.XXXXXX)"
RENDERED_OUT="$(mktemp -t verify-tutor-patches-rendered.XXXXXX)"
RENDERED_ERR="$(mktemp -t verify-tutor-patches-rendered-err.XXXXXX)"
trap 'rm -f "$MANIFEST_OUT" "$MANIFEST_ERR" "$RENDERED_OUT" "$RENDERED_ERR"' EXIT

set +e
"$MANIFEST_VERIFY" >"$MANIFEST_OUT" 2>"$MANIFEST_ERR"
MANIFEST_RC=$?
set -e

RENDERED_STATUS="not_run"
RENDERED_RC=0
if [[ -d "$TUTOR_ENV/env" ]]; then
  set +e
  "$RENDERED_VERIFY" >"$RENDERED_OUT" 2>"$RENDERED_ERR"
  RENDERED_RC=$?
  set -e
  if [[ "$RENDERED_RC" -eq 0 ]]; then
    RENDERED_STATUS="pass"
  else
    RENDERED_STATUS="fail"
  fi
else
  RENDERED_STATUS="missing_tutor_env"
  RENDERED_RC=1
  {
    echo "ERROR: Tutor environment not found at $TUTOR_ENV"
    echo "Run ./scripts/infra/tutor-config-save.sh first, then ./scripts/infra/prepare-tutor-build-context.sh --target all."
  } >"$RENDERED_ERR"
fi

if [[ "$OUTPUT_MODE" == "json" ]]; then
  python3 - <<'PY' "$MANIFEST_RC" "$RENDERED_RC" "$RENDERED_STATUS" "$MANIFEST_OUT" "$MANIFEST_ERR" "$RENDERED_OUT" "$RENDERED_ERR"
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_rc = int(sys.argv[1])
rendered_rc = int(sys.argv[2])
rendered_status = sys.argv[3]
manifest_out = Path(sys.argv[4]).read_text(encoding="utf-8")
manifest_err = Path(sys.argv[5]).read_text(encoding="utf-8")
rendered_out = Path(sys.argv[6]).read_text(encoding="utf-8")
rendered_err = Path(sys.argv[7]).read_text(encoding="utf-8")

payload = {
    "entrypoint": "scripts/infra/verify-tutor-patches.sh",
    "legacy": True,
    "static_manifest_contract": {
        "status": "pass" if manifest_rc == 0 else "fail",
        "exit_code": manifest_rc,
        "stdout": manifest_out,
        "stderr": manifest_err,
    },
    "rendered_contract": {
        "status": rendered_status,
        "exit_code": rendered_rc,
        "stdout": rendered_out,
        "stderr": rendered_err,
    },
}
print(json.dumps(payload, indent=2))
PY
else
  echo "=== Tutor Patch Authority Contract ==="
  cat "$MANIFEST_OUT"
  cat "$MANIFEST_ERR" >&2
  echo
  echo "=== Rendered Tutor Contract ==="
  if [[ "$RENDERED_STATUS" == "missing_tutor_env" ]]; then
    cat "$RENDERED_ERR" >&2
  else
    cat "$RENDERED_OUT"
    cat "$RENDERED_ERR" >&2
  fi
fi

if [[ "$MANIFEST_RC" -ne 0 || "$RENDERED_RC" -ne 0 ]]; then
  exit 1
fi
