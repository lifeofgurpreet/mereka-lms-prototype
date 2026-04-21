#!/usr/bin/env bash
# Shared setup for apply-patches.sh patch modules.
# Sourced by apply-patches.sh before any patch function.
# Provides: REPO_ROOT, PATCH_TEMPLATE_VARS (associative array of template paths)

# Guard against double-sourcing
if [[ -n "${_PATCH_COMMON_LOADED:-}" ]]; then
  return 0
fi
_PATCH_COMMON_LOADED=1

set -euo pipefail

# REPO_ROOT must be set by the caller (apply-patches.sh)
: "${REPO_ROOT:?REPO_ROOT must be set before sourcing _common.sh}"

# Activate local venv when available (idempotent).
# CI may provide Python through runner tooling without a repo-local .venv.
if [[ -z "${VIRTUAL_ENV:-}" && -f "$REPO_ROOT/.venv/bin/activate" ]]; then
  source "$REPO_ROOT/.venv/bin/activate"
fi

PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"
if [[ -z "${PYTHON_BIN}" ]]; then
  echo "python3 or python is required to discover Tutor template paths" >&2
  return 127
fi

# Discover Tutor template paths via Python introspection.
# Each variable is exported so patch functions can reference them.
_discover_template_paths() {
  export MFE_TEMPLATE
  MFE_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
import inspect
import tutormfe
from pathlib import Path
print(Path(inspect.getfile(tutormfe)).parent / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
PY
)

  export MYSQL_TEMPLATE
  MYSQL_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "local" / "docker-compose.yml")
PY
)

  export OPENEDX_TEMPLATE
  OPENEDX_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "Dockerfile")
PY
)

  export CADDY_TEMPLATE
  CADDY_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "caddy" / "Caddyfile")
PY
)

  export NGINX_LMS_TEMPLATE
  NGINX_LMS_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "nginx" / "lms.conf")
PY
)

  export LMS_SETTINGS_TEMPLATE
  LMS_SETTINGS_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "openedx" / "settings" / "lms" / "production.py")
PY
)

  export LMS_ASSETS_TEMPLATE
  LMS_ASSETS_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "lms" / "assets.py")
PY
)

  export CMS_ASSETS_TEMPLATE
  CMS_ASSETS_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "cms" / "assets.py")
PY
)

  export WEBPACK_PROD_TEMPLATE
  WEBPACK_PROD_TEMPLATE=$("${PYTHON_BIN}" - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "edx-platform" / "webpack.prod.config.js")
PY
)
}

# Run template discovery once
_discover_template_paths
