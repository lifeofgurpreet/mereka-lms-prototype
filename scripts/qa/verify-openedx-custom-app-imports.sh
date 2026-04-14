#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/verify-openedx-custom-app-imports.sh --image-ref <registry/repo:tag|@digest>
EOF
}

IMAGE_REF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-ref) IMAGE_REF="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$IMAGE_REF" ]]; then
  echo "Missing required argument: --image-ref" >&2
  usage >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN_MAIN="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py"

if [[ ! -f "$PLUGIN_MAIN" ]]; then
  echo "FAIL missing Tutor dockerfile patch: $PLUGIN_MAIN" >&2
  exit 1
fi

APPS_JSON="$(python3 - "$PLUGIN_MAIN" <<'PY'
from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

plugin = Path(sys.argv[1])
tree = ast.parse(plugin.read_text(encoding="utf-8"), filename=str(plugin))
lists: dict[str, list[str]] = {}


def eval_string_list(node: ast.AST) -> list[str]:
    if isinstance(node, ast.List):
        values: list[str] = []
        for elt in node.elts:
            if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                values.append(elt.value)
            elif isinstance(elt, ast.Starred) and isinstance(elt.value, ast.Name):
                values.extend(lists[elt.value.id])
            else:
                raise ValueError(f"unsupported list element: {ast.dump(elt)}")
        return values
    if isinstance(node, ast.Name):
        return list(lists[node.id])
    raise ValueError(f"unsupported list expression: {ast.dump(node)}")


for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    for target in node.targets:
        if isinstance(target, ast.Name) and target.id.endswith("_CUSTOM_APPS"):
            lists[target.id] = eval_string_list(node.value)

print(json.dumps(lists.get("_CUSTOM_APPS", [])))
PY
)"

echo "=== OpenEdX Custom App Import Verification ==="
echo "Image: $IMAGE_REF"
echo "Pulling image if needed..."
docker pull "$IMAGE_REF" >/dev/null

docker run --rm --entrypoint python "$IMAGE_REF" -c '
import importlib
import json
import sys

apps = json.loads(sys.argv[1])
failures = []

for app in apps:
    for module_name in (app, f"{app}.apps"):
        try:
            importlib.import_module(module_name)
            print(f"  PASS  {module_name}")
        except Exception as exc:
            failures.append((module_name, repr(exc)))
            print(f"  FAIL  {module_name}: {exc}")

if failures:
    print("")
    print(f"Import verification failed for {len(failures)} module(s).", file=sys.stderr)
    sys.exit(1)

print("")
print(f"Verified {len(apps)} custom apps inside the built image.")
' "$APPS_JSON"
