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

# Activate venv (idempotent)
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  source "$REPO_ROOT/.venv/bin/activate"
fi

# Discover Tutor template paths via Python introspection.
# Each variable is exported so patch functions can reference them.
_discover_template_paths() {
  MFE_TEMPLATE=$(python - <<'PY'
import inspect
import tutormfe
from pathlib import Path
print(Path(inspect.getfile(tutormfe)).parent / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
PY
)

  MFE_INDIGO_ENV_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutorindigo
print(Path(tutorindigo.__file__).parent / "templates" / "indigo" / "env.config.jsx")
PY
)

  MYSQL_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "local" / "docker-compose.yml")
PY
)

  OPENEDX_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "Dockerfile")
PY
)

  CADDY_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "caddy" / "Caddyfile")
PY
)

  NGINX_LMS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "nginx" / "lms.conf")
PY
)

  LMS_SETTINGS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "openedx" / "settings" / "lms" / "production.py")
PY
)

  LMS_ASSETS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "lms" / "assets.py")
PY
)

  CMS_ASSETS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "cms" / "assets.py")
PY
)

  WEBPACK_PROD_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "edx-platform" / "webpack.prod.config.js")
PY
)
}

# Run template discovery once
_discover_template_paths
