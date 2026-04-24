#!/usr/bin/env bash
# @spec: plans/paragon-design-tokens-migration_spec.md
# Sync canonical CSS tokens into tokens/src/core/global.json.
#
# Default mode is dry-run; use --apply to persist or --check for CI drift gates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSS_FILE="$REPO_ROOT/assets/branding/tokens.css"
JSON_FILE="$REPO_ROOT/tokens/src/core/global.json"
APPLY=0
CHECK=0

usage() {
  cat <<'EOF'
Usage: scripts/branding/sync-tokens-to-json.sh [--apply|--check]

Options:
  --apply   Write updates to tokens/src/core/global.json
  --check   Exit non-zero when updates would be required
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --check) CHECK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$APPLY" -eq 1 && "$CHECK" -eq 1 ]]; then
  echo "ERROR: --apply and --check are mutually exclusive" >&2
  exit 1
fi

if [[ ! -f "$CSS_FILE" ]]; then
  echo "ERROR: missing canonical CSS token file: ${CSS_FILE#$REPO_ROOT/}" >&2
  exit 1
fi
if [[ ! -f "$JSON_FILE" ]]; then
  echo "ERROR: missing token JSON file: ${JSON_FILE#$REPO_ROOT/}" >&2
  exit 1
fi

python3 - "$CSS_FILE" "$JSON_FILE" "$APPLY" "$CHECK" <<'PY'
import json
import re
import sys
from pathlib import Path

css_file = Path(sys.argv[1])
json_file = Path(sys.argv[2])
apply_changes = sys.argv[3] == "1"
check_only = sys.argv[4] == "1"

css_text = css_file.read_text(encoding="utf-8")
json_data = json.loads(json_file.read_text(encoding="utf-8"))

css_vars = {
    f"--{name}": value.strip()
    for name, value in re.findall(r"--([A-Za-z0-9_-]+)\s*:\s*([^;]+);", css_text)
}

mapping = {
    ("global", "color", "black"): "--color-black",
    ("global", "color", "white"): "--color-white",
    ("global", "color", "teal"): "--color-teal",
    ("global", "color", "magenta"): "--color-magenta",
    ("global", "color", "magentaDark"): "--color-magenta-dark",
    ("global", "color", "blue"): "--color-blue",
    ("global", "color", "burgundy"): "--color-burgundy",
    ("global", "color", "pink"): "--color-pink",
    ("global", "color", "sky"): "--color-sky",
    ("global", "color", "orange"): "--color-orange",
    ("global", "color", "gold"): "--color-gold",
    ("global", "color", "mint"): "--color-mint",
    ("global", "color", "periwinkle"): "--color-periwinkle",
    ("global", "color", "forest"): "--color-forest",
    ("global", "color", "success"): "--color-success",
    ("global", "color", "successLight"): "--color-success-light",
    ("global", "color", "warning"): "--color-warning",
    ("global", "color", "warningDark"): "--color-warning-dark",
    ("global", "color", "error"): "--color-error",
    ("global", "color", "errorLight"): "--color-error-light",
    ("global", "color", "info"): "--color-info",
    ("global", "color", "infoLight"): "--color-info-light",
    ("global", "color", "ink900"): "--color-black",
    ("global", "color", "ink700"): "--gray-700",
    ("global", "color", "ink500"): "--gray-500",
    ("global", "color", "ink300"): "--gray-400",
    ("global", "color", "surfacePrimary"): "--color-white",
    ("global", "color", "surfaceSecondary"): "--gray-100",
    ("global", "color", "border"): "--pgn-border-color",
    ("global", "color", "borderStrong"): "--gray-500",
    ("global", "typography", "fontFamilyBody"): "--font-body",
    ("global", "typography", "fontFamilyHeading"): "--font-heading",
    ("global", "typography", "fontFamilyVideo"): "--font-video",
    ("global", "typography", "fontSizeDisplay"): "--text-display",
    ("global", "typography", "fontSizeH1"): "--text-h1",
    ("global", "typography", "fontSizeH2"): "--text-h2",
    ("global", "typography", "fontSizeH3"): "--text-h3",
    ("global", "typography", "fontSizeH4"): "--text-h4",
    ("global", "typography", "fontSizeBodyLg"): "--text-body-lg",
    ("global", "typography", "fontSizeBody"): "--text-body",
    ("global", "typography", "fontSizeBodySm"): "--text-body-sm",
    ("global", "typography", "fontSizeCaption"): "--text-caption",
    ("global", "typography", "lineHeightDisplay"): "--leading-display",
    ("global", "typography", "lineHeightHeading"): "--leading-heading",
    ("global", "typography", "lineHeightBody"): "--leading-body",
    ("global", "typography", "fontWeightRegular"): "400",
    ("global", "typography", "fontWeightMedium"): "500",
    ("global", "typography", "fontWeightSemiBold"): "600",
    ("global", "typography", "fontWeightBold"): "700",
    ("global", "typography", "letterSpacingBadge"): "--mereka-mfe-badge-letter-spacing",
    ("global", "spacing", "0"): "--space-0",
    ("global", "spacing", "1"): "--space-1",
    ("global", "spacing", "2"): "--space-2",
    ("global", "spacing", "3"): "--space-3",
    ("global", "spacing", "4"): "--space-4",
    ("global", "spacing", "5"): "--space-5",
    ("global", "spacing", "6"): "--space-6",
    ("global", "spacing", "8"): "--space-8",
    ("global", "spacing", "10"): "--space-10",
    ("global", "spacing", "12"): "--space-12",
    ("global", "spacing", "16"): "--space-16",
    ("global", "spacing", "20"): "--space-20",
    ("global", "spacing", "24"): "--space-24",
    ("global", "sizing", "avatarXs"): "--avatar-xs",
    ("global", "sizing", "avatarSm"): "--avatar-sm",
    ("global", "sizing", "avatarMd"): "--avatar-md",
    ("global", "sizing", "avatarLg"): "--avatar-lg",
    ("global", "sizing", "avatarXl"): "--avatar-xl",
    ("global", "sizing", "avatar2xl"): "--avatar-2xl",
    ("global", "sizing", "iconSm"): "--icon-sm",
    ("global", "sizing", "iconMd"): "--icon-md",
    ("global", "sizing", "iconLg"): "--icon-lg",
    ("global", "sizing", "iconXl"): "--icon-xl",
    ("global", "sizing", "buttonHeightDefault"): "--button-height-default",
    ("global", "sizing", "buttonHeightLarge"): "--button-height-large",
    ("global", "sizing", "navbarLogoHeight"): "--mereka-mfe-navbar-logo-height",
    ("global", "sizing", "authnCtaMinHeight"): "--mereka-mfe-authn-cta-min-height",
    ("global", "shadow", "sm"): "--shadow-sm",
    ("global", "shadow", "md"): "--shadow-md",
    ("global", "shadow", "lg"): "--shadow-lg",
    ("global", "shadow", "xl"): "--shadow-xl",
    ("global", "zIndex", "dropdown"): "--z-dropdown",
    ("global", "zIndex", "sticky"): "--z-sticky",
    ("global", "zIndex", "fixed"): "--z-fixed",
    ("global", "zIndex", "modalBackdrop"): "--z-modal-backdrop",
    ("global", "zIndex", "modal"): "--z-modal",
    ("global", "zIndex", "popover"): "--z-popover",
    ("global", "zIndex", "tooltip"): "--z-tooltip",
    ("global", "animation", "durationFast"): "--duration-100",
    ("global", "animation", "durationBase"): "--duration-200",
    ("global", "animation", "durationSlow"): "--duration-300",
    ("global", "animation", "easingIn"): "--ease-in",
    ("global", "animation", "easingOut"): "--ease-out",
    ("global", "animation", "easingStandard"): "--ease-in-out",
    ("global", "animation", "transitionBase"): "--pgn-transition-base",
    ("global", "animation", "transitionFade"): "--pgn-transition-fade",
    ("global", "radius", "none"): "--radius-none",
    ("global", "radius", "sm"): "--radius-sm",
    ("global", "radius", "md"): "--radius-md",
    ("global", "radius", "lg"): "--radius-lg",
    ("global", "radius", "xl"): "--radius-xl",
    ("global", "radius", "full"): "--radius-full",
}

changes = []

def get_path_value(data, path):
    cur = data
    for p in path:
        cur = cur[p]
    return cur["value"]

def set_path_value(data, path, value):
    cur = data
    for p in path:
        cur = cur[p]
    cur["value"] = value

for path, source in mapping.items():
    if source.startswith("--"):
        if source not in css_vars:
            continue
        value = css_vars[source]
    else:
        value = source

    # Split button paddings into Y/X where needed.
    if path[-1] == "buttonPaddingDefaultY" and "--button-padding-default" in css_vars:
        value = css_vars["--button-padding-default"].split()[0]
    elif path[-1] == "buttonPaddingDefaultX" and "--button-padding-default" in css_vars:
        parts = css_vars["--button-padding-default"].split()
        value = parts[1] if len(parts) > 1 else parts[0]
    elif path[-1] == "buttonPaddingLargeY" and "--button-padding-large" in css_vars:
        value = css_vars["--button-padding-large"].split()[0]
    elif path[-1] == "buttonPaddingLargeX" and "--button-padding-large" in css_vars:
        parts = css_vars["--button-padding-large"].split()
        value = parts[1] if len(parts) > 1 else parts[0]
    elif path[-1] == "transitionTransform":
        value = "transform 0.2s ease-in-out 0s normal"

    current = get_path_value(json_data, path)
    if str(current) != str(value):
        changes.append((".".join(path), current, value))
        set_path_value(json_data, path, value)

if apply_changes:
    mode = "APPLY"
elif check_only:
    mode = "CHECK"
else:
    mode = "DRY-RUN"
print(f"[{mode}] updates: {len(changes)}")
for name, old, new in changes:
    print(f"  {name}: {old!r} -> {new!r}")

if apply_changes and changes:
    json_file.write_text(json.dumps(json_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"[APPLY] wrote {json_file}")
elif check_only and changes:
    print("[CHECK] drift detected")
    raise SystemExit(1)
elif check_only:
    print("[CHECK] no drift")
elif not apply_changes:
    print("[DRY-RUN] no file changes written (use --apply to persist)")
PY
