#!/usr/bin/env bash
# Remove Tutor's obsolete activation_key git-am layer for supported Ulmo refs.
# Upstream edx-platform release/ulmo already contains commit
# 21cead238466ca398ba368518f1d3288431d68f4, so replaying it now breaks clean
# local builds instead of adding missing security coverage.
set -euo pipefail

apply_openedx_obsolete_activation_key_patch_removal_patch() {
  local dockerfile="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/Dockerfile"

  if [[ ! -f "$dockerfile" ]]; then
    echo "Rendered Open edX Dockerfile missing: $dockerfile" >&2
    return 1
  fi

  "${PYTHON_BIN:-python3}" - "$dockerfile" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

exact_block = (
    "# SECURITY FIX: remove activation_key exposure from account API\n"
    "RUN curl -fsSL https://github.com/openedx/openedx-platform/commit/"
    "21cead238466ca398ba368518f1d3288431d68f4.patch | git am\n"
)

if exact_block in text:
    path.write_text(text.replace(exact_block, "", 1), encoding="utf-8")
    raise SystemExit(0)

if "21cead238466ca398ba368518f1d3288431d68f4" not in text and "activation_key exposure" not in text:
    raise SystemExit(0)

if re.search(r"activation_key.*git am|git am.*activation_key", text, flags=re.IGNORECASE | re.DOTALL):
    raise SystemExit(
        "Upstream Open edX Dockerfile activation-key patch selector changed; "
        f"revalidate authority before updating {path}"
    )

raise SystemExit(0)
PY
}
