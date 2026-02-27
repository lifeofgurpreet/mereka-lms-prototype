#!/usr/bin/env bash
set -euo pipefail

# Transitional runtime theme-generation script.
# Produces the four files required by PARAGON_THEME_URLS:
# - core.min.css
# - light.min.css
# - mereka-brand.min.css
# - mereka-brand-light.min.css

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
OUTPUT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$TOKENS_SCSS" ]]; then
  echo "ERROR: missing token source $TOKENS_SCSS" >&2
  exit 1
fi

write_core_theme() {
  local target="$1"
  local core_sources=(
    "$REPO_ROOT/node_modules/@edx/paragon/dist/css/core.min.css"
    "$REPO_ROOT/node_modules/@edx/paragon/dist/css/core.css"
    "$REPO_ROOT/node_modules/@openedx/paragon/dist/css/core.min.css"
    "$REPO_ROOT/node_modules/@openedx/paragon/dist/css/core.css"
  )

  for candidate in "${core_sources[@]}"; do
    if [[ -f "$candidate" ]]; then
      cp "$candidate" "$target"
      return
    fi
  done

  cat > "$target" <<'CSS'
:root {
  /* fallback core theme */
}
CSS
}

write_core_theme "$OUTPUT_DIR/core.min.css"
cp "$OUTPUT_DIR/core.min.css" "$OUTPUT_DIR/light.min.css"

python3 - "$TOKENS_SCSS" "$OUTPUT_DIR/mereka-brand.min.css" <<'PY'
from pathlib import Path
import re
import sys

PATH_TOKENS = Path(sys.argv[1])
PATH_BRAND = Path(sys.argv[2])

text = PATH_TOKENS.read_text(encoding="utf-8")

var_def_re = re.compile(r"^\s*\$([A-Za-z0-9_-]+):\s*(.+?)\s*;\s*$")
var_ref_re = re.compile(r"#\{\$([A-Za-z0-9_-]+)\}")
var_plain_re = re.compile(r"\$([A-Za-z0-9_-]+)")

vars = {}
for line in text.splitlines():
    m = var_def_re.match(line)
    if m:
        vars[m.group(1)] = m.group(2)


def resolve_var(name, depth=0):
    if depth > 32:
        return vars.get(name, f"#{{${name}}}")
    raw = vars.get(name)
    if raw is None:
        return f"#{{${name}}}"
    resolved = var_ref_re.sub(lambda m: resolve_var(m.group(1), depth + 1), raw)
    resolved = var_plain_re.sub(lambda m: resolve_var(m.group(1), depth + 1), resolved)
    return resolved


root_match = re.search(r":root\s*\{(.*?)\n\}", text, re.S)
if not root_match:
    raise SystemExit("Unable to locate :root block in _tokens.scss")

pgn_lines = []
for raw in root_match.group(1).splitlines():
    line = raw.rstrip()
    stripped = line.strip()
    if not stripped.startswith("--pgn-"):
        continue
    if ";" not in stripped:
        continue

    name, value = stripped.split(":", 1)
    value = value.strip()
    if value.endswith(";"):
        value = value[:-1].strip()

    resolved = var_ref_re.sub(lambda m: resolve_var(m.group(1)), value)
    resolved = var_plain_re.sub(lambda m: resolve_var(m.group(1)), resolved)

    # Keep all CSS functions/variables untouched, only expand SCSS interpolation.
    pgn_lines.append(f"  {name}: {resolved};")

if not pgn_lines:
    raise SystemExit("No --pgn-* properties found in _tokens.scss")

payload = ":root {\n" + "\n".join(pgn_lines) + "\n}\n"
PATH_BRAND.write_text(payload, encoding="utf-8")
PATH_BRAND.with_name("mereka-brand-light.min.css").write_text(payload, encoding="utf-8")
PY

echo "Wrote theme assets to $OUTPUT_DIR"
