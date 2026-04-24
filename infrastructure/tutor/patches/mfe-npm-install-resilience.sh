#!/usr/bin/env bash
# Patch rendered MFE Dockerfile npm install layers with retry + fallback.
set -euo pipefail

apply_mfe_npm_install_resilience_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local dockerfile="$tutor_root/env/plugins/mfe/build/mfe/Dockerfile"

  if [[ ! -f "$dockerfile" ]]; then
    echo "Rendered MFE Dockerfile missing: $dockerfile" >&2
    return 1
  fi

  "${PYTHON_BIN}" - "$dockerfile" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

replacement = (
    "# mfe-npm-install-resilience-sentinel - apply-patches.sh\n"
    "RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c "
    "'npm config set fetch-retries 6; "
    "npm config set fetch-retry-mintimeout 20000; "
    "npm config set fetch-retry-maxtimeout 120000; "
    "npm config set fetch-timeout 300000; "
    "for attempt in 1 2 3; do "
    "npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; "
    "echo \"npm clean-install attempt ${attempt} failed; attempting npm install fallback\" >&2; "
    "npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; "
    "echo \"npm install fallback attempt ${attempt} failed; retrying in 15s\" >&2; "
    "sleep 15; done; exit 1'"
)

if "mfe-npm-install-resilience-sentinel" in text:
    if "npm config set fetch-retries 6" in text:
        raise SystemExit(0)
    sentinel_pattern = re.compile(
        r"^# mfe-npm-install-resilience-sentinel - apply-patches\.sh\n"
        r"RUN --mount=type=cache,target=/root/\.npm,sharing=shared bash -o pipefail -c '[^\n]*'$",
        re.MULTILINE,
    )
    updated, count = sentinel_pattern.subn(replacement, text)
    if count == 0:
        raise SystemExit(
            "Existing MFE npm resilience sentinel shape changed; revalidate render authority "
            f"before updating {path}"
        )
    path.write_text(updated, encoding="utf-8")
    print(f"Upgraded {count} MFE npm resilience layer(s) with npm retry configuration")
    raise SystemExit(0)

pattern = re.compile(
    r"^RUN --mount=type=cache,target=/root/\.npm,sharing=shared "
    r"npm clean-install --no-audit --no-fund --registry=\$NPM_REGISTRY$",
    re.MULTILINE,
)

updated, count = pattern.subn(replacement, text)
if count == 0:
    raise SystemExit(
        "Upstream MFE Dockerfile changed; resilience patch selector no longer matches. "
        f"Revalidate render authority before updating {path}"
    )

path.write_text(updated, encoding="utf-8")
print(f"Wrapped {count} MFE npm install layer(s) with clean-install retry and install fallback")
PY
}
