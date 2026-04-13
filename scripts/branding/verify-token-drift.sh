#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-012
# @spec: design-tokens-system_spec.md
# Ensure runtime token exports do not drift from the canonical design tokens.
#
# Canonical source in this repo: assets/branding/tokens.css
# Runtime exports: infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
# Provenance lock: assets/branding/tokens.provenance.json
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_PROVENANCE="$REPO_ROOT/assets/branding/tokens.provenance.json"
OVERRIDES_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
SCOPE_MODE="${VERIFY_TOKEN_DRIFT_BRANDING_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_TOKEN_DRIFT_BRANDING_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      scripts/branding/verify-token-drift.sh|\
      assets/branding/tokens.css|\
      assets/branding/tokens.provenance.json|\
      infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-token-drift (scope skip: no token-drift authority changes)"
  exit 0
fi

if [[ ! -f "$TOKENS_CSS" ]]; then
  echo "Missing canonical tokens: $TOKENS_CSS" >&2
  exit 1
fi
if [[ ! -f "$TOKENS_PROVENANCE" ]]; then
  echo "Missing token provenance lock file: $TOKENS_PROVENANCE" >&2
  exit 1
fi
if [[ ! -f "$OVERRIDES_CSS" ]]; then
  echo "Missing runtime overrides: $OVERRIDES_CSS" >&2
  exit 1
fi

python3 - "$TOKENS_CSS" "$OVERRIDES_CSS" "$TOKENS_PROVENANCE" <<'PY'
import hashlib
import json
import re
import sys

tokens_path = sys.argv[1]
overrides_path = sys.argv[2]
provenance_path = sys.argv[3]


def parse_root_vars(css: str) -> dict[str, str]:
    # Parse :root { --var: value; } blocks. We intentionally keep this simple:
    # these files are owned by us and are formatted predictably.
    roots = []
    for match in re.finditer(r":root\s*\{(.*?)\}", css, re.S):
        roots.append(match.group(1))
    text = "\n".join(roots)
    out: dict[str, str] = {}
    for match in re.finditer(r"(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);", text):
        key = match.group(1).strip()
        value = re.sub(r"\s+", " ", match.group(2).strip())
        out[key] = value
    return out


with open(tokens_path, "r", encoding="utf-8") as file:
    tokens_css = file.read()
with open(overrides_path, "r", encoding="utf-8") as file:
    overrides_css = file.read()
with open(provenance_path, "r", encoding="utf-8") as file:
    provenance = json.load(file)

tokens = parse_root_vars(tokens_css)
overrides = parse_root_vars(overrides_css)
failures: list[str] = []

required_provenance_fields = (
    "source_repo",
    "source_path",
    "source_commit",
    "source_sha256",
)
for key in required_provenance_fields:
    if not provenance.get(key):
        failures.append(f"tokens provenance missing key: {key}")

source_commit = str(provenance.get("source_commit", ""))
if source_commit and not re.fullmatch(r"[0-9a-f]{40}", source_commit):
    failures.append("tokens provenance source_commit must be a 40-char lowercase git sha")

source_sha = str(provenance.get("source_sha256", "")).lower()
if source_sha and not re.fullmatch(r"[0-9a-f]{64}", source_sha):
    failures.append("tokens provenance source_sha256 must be a 64-char lowercase sha256")

actual_sha = hashlib.sha256(tokens_css.encode("utf-8")).hexdigest()
if source_sha and source_sha != actual_sha:
    failures.append(
        f"tokens.css sha256 drift: provenance={source_sha} actual={actual_sha}. "
        "Refresh tokens.provenance.json after intentional token updates."
    )

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
for token_var, override_var in required_pairs:
    token_value = tokens.get(token_var)
    override_value = overrides.get(override_var)
    if not token_value:
        failures.append(f"missing {token_var} in tokens.css")
        continue
    if not override_value:
        failures.append(f"missing {override_var} in overrides.css")
        continue
    token_norm = token_value.strip().lower().replace('"', "").replace("'", "")
    override_norm = override_value.strip().lower().replace('"', "").replace("'", "")
    if token_norm != override_norm:
        failures.append(f"drift: {token_var}={token_value} != {override_var}={override_value}")


def require_substring(var: str, substr: str, *, where: str):
    value = tokens.get(var) if where == "tokens" else overrides.get(var)
    if not value:
        failures.append(f"missing {var} in {where}")
        return
    if substr.lower() not in value.lower():
        failures.append(f"{var} in {where} missing '{substr}' (got: {value})")


# Ensure font names align with design tokens (we don't require exact stacks).
require_substring("--font-heading", "Lato", where="tokens")
require_substring("--font-body", "Poppins", where="tokens")
require_substring("--mereka-font-heading", "Lato", where="overrides")
require_substring("--mereka-font-body", "Poppins", where="overrides")

if failures:
    print("✗ Token drift detected:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print("✓ Token drift + provenance checks passed.")
PY
