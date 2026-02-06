#!/usr/bin/env bash
# Ensure runtime token exports do not drift from the canonical design tokens.
#
# Canonical source in this repo: assets/branding/tokens.css
# Runtime exports: infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
OVERRIDES_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"

if [[ ! -f "$TOKENS_CSS" ]]; then
  echo "Missing canonical tokens: $TOKENS_CSS" >&2
  exit 1
fi
if [[ ! -f "$OVERRIDES_CSS" ]]; then
  echo "Missing runtime overrides: $OVERRIDES_CSS" >&2
  exit 1
fi

python3 - "$TOKENS_CSS" "$OVERRIDES_CSS" <<'PY'
import re
import sys

tokens_path = sys.argv[1]
overrides_path = sys.argv[2]

def parse_root_vars(css: str) -> dict[str, str]:
    # Parse :root { --var: value; } blocks. We intentionally keep this simple:
    # these files are owned by us and are formatted predictably.
    roots = []
    for m in re.finditer(r":root\s*\{(.*?)\}", css, re.S):
        roots.append(m.group(1))
    text = "\n".join(roots)
    out: dict[str, str] = {}
    for m in re.finditer(r"(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);", text):
        k = m.group(1).strip()
        v = re.sub(r"\s+", " ", m.group(2).strip())
        out[k] = v
    return out

with open(tokens_path, "r", encoding="utf-8") as f:
    tokens_css = f.read()
with open(overrides_path, "r", encoding="utf-8") as f:
    overrides_css = f.read()

tokens = parse_root_vars(tokens_css)
overrides = parse_root_vars(overrides_css)

required_pairs = [
    ("--color-black", "--mereka-color-ink-900"),
    ("--color-teal", "--mereka-color-teal"),
    ("--color-magenta", "--mereka-color-magenta"),
    ("--color-blue", "--mereka-color-blue"),
    ("--color-sky", "--mereka-color-sky"),
    ("--color-burgundy", "--mereka-color-danger"),
    ("--color-pink", "--mereka-color-danger-soft"),
    ("--color-gold", "--mereka-color-warning"),
    ("--color-forest", "--mereka-color-success"),
]

failures: list[str] = []
for token_var, override_var in required_pairs:
    tv = tokens.get(token_var)
    ov = overrides.get(override_var)
    if not tv:
        failures.append(f"missing {token_var} in tokens.css")
        continue
    if not ov:
        failures.append(f"missing {override_var} in overrides.css")
        continue
    # Normalize quotes/case for hex strings.
    tv_norm = tv.strip().lower().replace('"', "").replace("'", "")
    ov_norm = ov.strip().lower().replace('"', "").replace("'", "")
    if tv_norm != ov_norm:
        failures.append(f"drift: {token_var}={tv} != {override_var}={ov}")

def require_substring(var: str, substr: str, *, where: str):
    v = tokens.get(var) if where == "tokens" else overrides.get(var)
    if not v:
        failures.append(f"missing {var} in {where}")
        return
    if substr.lower() not in v.lower():
        failures.append(f"{var} in {where} missing '{substr}' (got: {v})")

# Ensure font names align with design tokens (we don't require exact stacks).
require_substring("--font-heading", "Lato", where="tokens")
require_substring("--font-body", "Poppins", where="tokens")
require_substring("--mereka-font-heading", "Lato", where="overrides")
require_substring("--mereka-font-body", "Poppins", where="overrides")

if failures:
    print("✗ Token drift detected:")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print("✓ Token drift check passed (tokens.css matches runtime exports).")
PY

