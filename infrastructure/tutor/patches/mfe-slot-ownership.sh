#!/usr/bin/env bash
# Patch: remove tutor-indigo learner MFE layout ownership from generated env.config.jsx.
#
# Tutor Indigo still injects footer/header/theme widgets for learner-facing MFEs
# during `tutor config save`. Mereka owns those same surfaces via local
# PLUGIN_SLOTS, so shipping both produces split ownership and ambiguous runtime
# behavior. This patch strips the Indigo app-specific blocks from the generated
# env.config artifacts after Tutor renders them.

apply_mfe_slot_ownership_patch() {
  local candidates=(
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
  )

  "${PYTHON_BIN}" - "${candidates[@]}" <<'PY'
from pathlib import Path
import re
import sys

APPS = ("learning", "learner-dashboard", "profile", "account", "discussions")
FOREIGN_MARKERS = (
    "RenderWidget: IndigoFooter",
    "RenderWidget: AddDarkTheme",
    "RenderWidget: ToggleThemeButton",
    "RenderWidget: MobileViewHeader",
)


def strip_app_block(text: str, app: str) -> tuple[str, bool]:
    pattern = re.compile(
        rf"(?ms)^[ \t]*if \(process\.env\.APP_ID == '{re.escape(app)}'\) \{{\n.*?^[ \t]*\}}\n",
    )
    match = pattern.search(text)
    if not match:
        return text, False

    block = match.group(0)
    if not any(marker in block for marker in FOREIGN_MARKERS):
        return text, False

    updated = text[: match.start()] + "\n" + text[match.end() :]
    return updated, True


for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.exists():
        continue

    original = path.read_text(encoding="utf-8")
    updated = original
    stripped_apps: list[str] = []

    for app in APPS:
        updated, changed = strip_app_block(updated, app)
        if changed:
            stripped_apps.append(app)

    if updated != original:
        path.write_text(updated, encoding="utf-8")
        print(
            "Stripped tutor-indigo learner MFE slot ownership from"
            f" {path}: {', '.join(stripped_apps)}"
        )
    else:
        print(f"No tutor-indigo learner MFE slot ownership found in {path}")
PY
}
