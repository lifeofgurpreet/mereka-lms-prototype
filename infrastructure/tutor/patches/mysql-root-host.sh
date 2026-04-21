#!/usr/bin/env bash
# Ensure local MySQL root can be reached by sibling Tutor containers.
set -euo pipefail

apply_mysql_root_host_patch() {
  local compose_file="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/local/docker-compose.yml"

  if [[ ! -f "$compose_file" ]]; then
    echo "Rendered local docker-compose.yml missing: $compose_file" >&2
    return 1
  fi

  python3 - "$compose_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

match = re.search(r"(?ms)^  mysql:\n(?P<body>.*?)(?=^  [a-zA-Z0-9_-]+:|\Z)", text)
if not match:
    raise SystemExit(f"mysql service not found in {path}")

body = match.group("body")
if "MYSQL_ROOT_HOST:" in body:
    raise SystemExit(0)

password_line = re.search(r"(?m)^      MYSQL_ROOT_PASSWORD: .*$", body)
if not password_line:
    raise SystemExit(f"MYSQL_ROOT_PASSWORD not found in mysql service in {path}")

insert_at = match.start("body") + password_line.end()
text = text[:insert_at] + '\n      MYSQL_ROOT_HOST: "%"' + text[insert_at:]
path.write_text(text, encoding="utf-8")
PY
}
