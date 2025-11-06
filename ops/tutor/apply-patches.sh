#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/.venv/bin/activate"

MFE_TEMPLATE=$(python - <<'PY'
import inspect
import tutormfe
from pathlib import Path
print(Path(inspect.getfile(tutormfe)) / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
PY
)

MYSQL_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "local" / "docker-compose.yml")
PY
)

PATCH_TARGETS=("$MFE_TEMPLATE" "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile" "$MYSQL_TEMPLATE" "$REPO_ROOT/tutor_env/env/local/docker-compose.yml")

python - "${PATCH_TARGETS[@]}" <<'PY'
from pathlib import Path
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # Ensure MFEs build against Node 18 with the required toolchain.
    if "docker.io/node:12-bullseye-slim" in updated:
        updated = updated.replace(
            "FROM docker.io/node:12-bullseye-slim",
            "FROM docker.io/node:18-bullseye-slim",
        )
    if "gcc git libgl1 libxi6 make" in updated:
        updated = updated.replace(
            "gcc git libgl1 libxi6 make",
            "gcc g++ git libgl1 libxi6 make python3 python3-distutils",
        )

    # Allow remote root access when using upstream MySQL images.
    if "MYSQL_ROOT_PASSWORD" in updated and "MYSQL_ROOT_HOST" not in updated:
        lines = updated.splitlines()
        new_lines = []
        for line in lines:
            new_lines.append(line)
            if "MYSQL_ROOT_PASSWORD" in line:
                indent = line[: len(line) - len(line.lstrip())]
                if "{{" in updated:
                    new_lines.append(
                        indent + 'MYSQL_ROOT_HOST: "{{ MYSQL_ROOT_HOST|default(\'%\') }}"'
                    )
                else:
                    new_lines.append(indent + 'MYSQL_ROOT_HOST: "%"')
        # Avoid duplicating the inserted line on successive runs.
        seen = False
        filtered = []
        for line in new_lines:
            if "MYSQL_ROOT_HOST" in line:
                if seen:
                    continue
                seen = True
            filtered.append(line)
        updated = "\n".join(filtered)
    # Normalize braces if a prior run introduced single-brace syntax.
    updated = updated.replace(
        "{ MYSQL_ROOT_HOST|default('%') }", "{{ MYSQL_ROOT_HOST|default('%') }}"
    )
    updated = updated.replace(
        "{{{ MYSQL_ROOT_HOST|default('%') }}}", "{{ MYSQL_ROOT_HOST|default('%') }}"
    )

    if updated != original:
        path.write_text(updated)
PY

echo "Applied local Tutor patches."
