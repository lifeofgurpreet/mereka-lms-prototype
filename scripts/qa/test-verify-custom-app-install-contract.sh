#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/scripts/qa/verify-custom-app-install-contract.sh"

tmpdir="$(mktemp -d -t verify-custom-app-install-contract.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/scripts/qa" "$tmpdir/infrastructure/tutor/plugins/_mereka_lms"
cp "$SOURCE_SCRIPT" "$tmpdir/scripts/qa/verify-custom-app-install-contract.sh"
chmod +x "$tmpdir/scripts/qa/verify-custom-app-install-contract.sh"

cat > "$tmpdir/infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py" <<'EOF_PATCH'
_CUSTOM_APPS = ["openedx_demo_app"]

_copy_lines = "\n".join(["COPY demo"])
_install_lines = "\n".join(["RUN pip install -e /openedx/custom-apps/openedx_demo_app"])
_runtime_copy_lines = "\n".join(
    [
        "COPY --from=python-requirements --chown=app:app /openedx/{app} /openedx/{app}"
    ]
)

PATCH_TEXT = """
{_copy_lines}
{_install_lines}
"""

FINAL_PATCH_NAME = "openedx-dockerfile-final"
FINAL_PATCH = """
{_runtime_copy_lines}
COPY --from=python-requirements --chown=app:app /openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy
"""
EOF_PATCH

mkdir -p "$tmpdir/infrastructure/tutor/custom-apps/openedx_demo_app"
cat > "$tmpdir/infrastructure/tutor/custom-apps/openedx_demo_app/__init__.py" <<'EOF_INIT'
"""openedx demo app"""
EOF_INIT
cat > "$tmpdir/infrastructure/tutor/custom-apps/openedx_demo_app/apps.py" <<'EOF_APPS'
from django.apps import AppConfig


class OpenedxDemoAppConfig(AppConfig):
    name = "openedx_demo_app"
EOF_APPS
cat > "$tmpdir/infrastructure/tutor/custom-apps/openedx_demo_app/setup.py" <<'EOF_SETUP'
from setuptools import setup

setup(name="openedx_demo_app", version="0.0.1")
EOF_SETUP

cd "$tmpdir"
if ./scripts/qa/verify-custom-app-install-contract.sh >/tmp/test-custom-app-install-pass.log 2>&1; then
  :
else
  echo "Expected baseline custom-app install contract to pass."
  cat /tmp/test-custom-app-install-pass.log
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py")
src = path.read_text()
path.write_text(src.replace('FINAL_PATCH_NAME = "openedx-dockerfile-final"\n', ''))
PY
if ./scripts/qa/verify-custom-app-install-contract.sh >/tmp/test-custom-app-runtime-copy-fail.log 2>&1; then
  echo "Expected fail when final-stage runtime carryover marker is missing."
  cat /tmp/test-custom-app-runtime-copy-fail.log
  exit 1
fi

if ! rg -q "openedx-dockerfile-final" /tmp/test-custom-app-runtime-copy-fail.log; then
  echo "Expected failure output to mention missing openedx-dockerfile-final contract."
  cat /tmp/test-custom-app-runtime-copy-fail.log
  exit 1
fi

cat > "$tmpdir/infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py" <<'EOF_PATCH'
_CUSTOM_APPS = ["openedx_demo_app"]

_copy_lines = "\n".join(["COPY demo"])
_install_lines = "\n".join(["RUN pip install -e /openedx/custom-apps/openedx_demo_app"])
_runtime_copy_lines = "\n".join(
    [
        "COPY --from=python-requirements --chown=app:app /openedx/{app} /openedx/{app}"
    ]
)

PATCH_TEXT = """
{_copy_lines}
{_install_lines}
"""

FINAL_PATCH_NAME = "openedx-dockerfile-final"
FINAL_PATCH = """
{_runtime_copy_lines}
COPY --from=python-requirements --chown=app:app /openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy
"""
EOF_PATCH

rm -f infrastructure/tutor/custom-apps/openedx_demo_app/setup.py
if ./scripts/qa/verify-custom-app-install-contract.sh >/tmp/test-custom-app-install-fail.log 2>&1; then
  echo "Expected fail when setup.py/pyproject.toml is missing."
  cat /tmp/test-custom-app-install-fail.log
  exit 1
fi

if ! rg -q "missing setup.py/pyproject.toml" /tmp/test-custom-app-install-fail.log; then
  echo "Expected failure output to mention missing setup.py/pyproject.toml."
  cat /tmp/test-custom-app-install-fail.log
  exit 1
fi

echo "PASS test-verify-custom-app-install-contract"
