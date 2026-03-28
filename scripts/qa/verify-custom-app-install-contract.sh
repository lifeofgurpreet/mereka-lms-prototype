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
import subprocess
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
    '_runtime_copy_lines = "\\n".join(',
    "{_copy_lines}",
    "{_install_lines}",
    "{_runtime_copy_lines}",
    "openedx-dockerfile-final",
    "COPY --from=python-requirements --chown=app:app /openedx/{app} /openedx/{app}",
    "COPY --from=python-requirements --chown=app:app /openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy",
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
print("--- Tracked runtime-artifact hygiene under custom-apps ---")

tracked_files: list[str] = []
git_root = None
git_root_probe = subprocess.run(
    ["git", "-C", str(custom_apps_dir), "rev-parse", "--show-toplevel"],
    text=True,
    capture_output=True,
)
if git_root_probe.returncode == 0:
    git_root = git_root_probe.stdout.strip()
if git_root:
    relative_target = str(custom_apps_dir.resolve().relative_to(Path(git_root).resolve()))
    try:
        tracked_files = subprocess.check_output(
            ["git", "-C", git_root, "ls-files", relative_target],
            text=True,
            stderr=subprocess.DEVNULL,
        ).splitlines()
        ok("Enumerated tracked files under custom-apps via git ls-files")
    except Exception as exc:
        fail(f"Unable to enumerate tracked files under custom-apps ({exc})")
        tracked_files = []
else:
    # In isolated fixtures without git metadata, fall back to filesystem scanning.
    tracked_files = [
        str(path.relative_to(custom_apps_dir.parent.parent.parent))
        for path in custom_apps_dir.rglob("*")
        if path.is_file()
    ]
    ok("Git metadata unavailable; scanned filesystem files under custom-apps")

runtime_artifact_violations: list[str] = []
for rel_path in tracked_files:
    rel = rel_path.strip()
    if not rel:
        continue
    normalized = rel.replace("\\", "/")
    if "/__pycache__/" in normalized or normalized.endswith("/__pycache__"):
        runtime_artifact_violations.append(f"{rel}: tracked __pycache__ content")
        continue
    if any(
        segment in normalized
        for segment in ("/.ruff_cache/", "/.pytest_cache/", "/.mypy_cache/", "/.hypothesis/")
    ):
        runtime_artifact_violations.append(f"{rel}: tracked tool cache content")
        continue
    if normalized.endswith((".pyc", ".pyo")):
        runtime_artifact_violations.append(f"{rel}: tracked compiled Python bytecode")
        continue
    if normalized.endswith((".sqlite", ".sqlite3", ".db")):
        runtime_artifact_violations.append(f"{rel}: tracked local database file")
        continue
    if normalized.endswith(
        (".sqlite-wal", ".sqlite-shm", ".sqlite-journal", ".sqlite3-wal", ".sqlite3-shm", ".sqlite3-journal", ".db-wal", ".db-shm", ".db-journal")
    ):
        runtime_artifact_violations.append(f"{rel}: tracked database sidecar file")
        continue
    if normalized.endswith((".log", ".pid", ".sock")):
        runtime_artifact_violations.append(f"{rel}: tracked runtime state file")
        continue
    if "/dist/" in normalized and not normalized.endswith("/.gitkeep"):
        runtime_artifact_violations.append(f"{rel}: tracked dist build artifact")
        continue

if runtime_artifact_violations:
    for violation in runtime_artifact_violations:
        fail(violation)
else:
    ok("No tracked runtime artifacts/caches detected in custom-apps")

print("")
print(f"Summary: PASS={passes} FAIL={fails}")
if fails:
    raise SystemExit(1)
PY
