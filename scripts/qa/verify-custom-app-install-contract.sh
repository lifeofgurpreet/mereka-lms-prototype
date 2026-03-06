#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE_PATCH="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py"
CUSTOM_APPS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps"

if [[ ! -f "$DOCKERFILE_PATCH" ]]; then
  echo "FAIL missing Tutor dockerfile patch: $DOCKERFILE_PATCH" >&2
  exit 1
fi
if [[ ! -d "$CUSTOM_APPS_DIR" ]]; then
  echo "FAIL missing custom apps directory: $CUSTOM_APPS_DIR" >&2
  exit 1
fi

python3 - "$DOCKERFILE_PATCH" "$CUSTOM_APPS_DIR" <<'PY'
from __future__ import annotations

import ast
import re
import sys
import tomllib
from pathlib import Path

dockerfile = Path(sys.argv[1])
custom_apps_dir = Path(sys.argv[2])

passes = 0
fails = 0


def ok(msg: str) -> None:
    global passes
    passes += 1
    print(f"  PASS {msg}")


def fail(msg: str) -> None:
    global fails
    fails += 1
    print(f"  FAIL {msg}")


def normalize_dist_name(name: str) -> str:
    return name.replace("-", "_").strip()


print("=== Custom App Install Contract Verification ===")
print(f"Dockerfile patch : {dockerfile}")
print(f"Custom apps dir  : {custom_apps_dir}")
print("")

src = dockerfile.read_text(encoding="utf-8")
tree = ast.parse(src, filename=str(dockerfile))

custom_apps: list[str] | None = None
for node in tree.body:
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == "_CUSTOM_APPS":
                if isinstance(node.value, (ast.List, ast.Tuple)):
                    values: list[str] = []
                    for elt in node.value.elts:
                        if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                            values.append(elt.value)
                    custom_apps = values
                break

if not custom_apps:
    fail("Unable to parse _CUSTOM_APPS from openedx_dockerfile.py")
    print(f"\nSummary: PASS={passes} FAIL={fails}")
    raise SystemExit(1)

ok(f"Parsed _CUSTOM_APPS list ({len(custom_apps)} entries)")

dupes = sorted({name for name in custom_apps if custom_apps.count(name) > 1})
if dupes:
    for name in dupes:
        fail(f"_CUSTOM_APPS contains duplicate entry: {name}")
else:
    ok("_CUSTOM_APPS has no duplicates")

for marker in (
    '_copy_lines = "\\n".join(',
    '_install_lines = "\\n".join(',
    "{_copy_lines}",
    "{_install_lines}",
):
    if marker in src:
        ok(f"Dockerfile patch contains contract marker: {marker}")
    else:
        fail(f"Dockerfile patch missing contract marker: {marker}")

print("")
print("--- Cross-check: _CUSTOM_APPS -> custom-app directories ---")

custom_dirs = sorted(p.name for p in custom_apps_dir.iterdir() if p.is_dir())

for app in custom_apps:
    app_dir = custom_apps_dir / app
    if not app_dir.is_dir():
        fail(f"{app}: listed in _CUSTOM_APPS but directory is missing")
        continue

    ok(f"{app}: directory exists")

    init_py = app_dir / "__init__.py"
    if init_py.is_file():
        ok(f"{app}: __init__.py exists")
    else:
        fail(f"{app}: missing __init__.py")

    apps_py = app_dir / "apps.py"
    if apps_py.is_file():
        ok(f"{app}: apps.py exists")
        apps_src = apps_py.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"name\s*=\s*['\"]([^'\"]+)['\"]", apps_src)
        if not match:
            fail(f"{app}: apps.py missing AppConfig name assignment")
        elif match.group(1).strip() != app:
            fail(f"{app}: AppConfig name is '{match.group(1).strip()}', expected '{app}'")
        else:
            ok(f"{app}: AppConfig name matches directory")
    else:
        fail(f"{app}: missing apps.py")

    setup_py = app_dir / "setup.py"
    pyproject = app_dir / "pyproject.toml"
    if setup_py.is_file():
        ok(f"{app}: setup.py exists")
        setup_src = setup_py.read_text(encoding="utf-8", errors="ignore")
        name_match = re.search(r"name\s*=\s*['\"]([^'\"]+)['\"]", setup_src)
        if not name_match:
            fail(f"{app}: setup.py missing package name field")
        else:
            dist_name = name_match.group(1).strip()
            if normalize_dist_name(dist_name) != app:
                fail(
                    f"{app}: setup.py name '{dist_name}' does not normalize to '{app}'"
                )
            else:
                ok(f"{app}: setup.py name maps to directory")
    elif pyproject.is_file():
        ok(f"{app}: pyproject.toml exists")
        try:
            data = tomllib.loads(pyproject.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"{app}: pyproject.toml parse error ({exc})")
            data = {}
        dist_name = (
            data.get("project", {}).get("name")
            if isinstance(data, dict)
            else None
        )
        if not dist_name:
            fail(f"{app}: pyproject.toml missing [project].name")
        elif normalize_dist_name(str(dist_name)) != app:
            fail(
                f"{app}: pyproject project.name '{dist_name}' does not normalize to '{app}'"
            )
        else:
            ok(f"{app}: pyproject project.name maps to directory")
    else:
        fail(f"{app}: missing setup.py/pyproject.toml")

print("")
print("--- Cross-check: directories -> _CUSTOM_APPS ---")
for app in custom_dirs:
    if app in custom_apps:
        ok(f"{app}: directory is included in _CUSTOM_APPS")
    else:
        # Fail hard: packaged app present but never copied/installed into openedx image.
        fail(f"{app}: directory exists but missing from _CUSTOM_APPS install map")

print("")
print(f"Summary: PASS={passes} FAIL={fails}")
if fails:
    raise SystemExit(1)
PY
