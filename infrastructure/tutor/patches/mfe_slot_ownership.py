#!/usr/bin/env python3
"""Helpers for stripping Tutor Indigo learner-MFE slot ownership blocks."""

from __future__ import annotations

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


def _find_app_block_bounds(text: str, app: str) -> tuple[int, int] | None:
    match = re.search(
        rf"^[ \t]*if \(process\.env\.APP_ID == '{re.escape(app)}'\) \{{",
        text,
        flags=re.MULTILINE,
    )
    if not match:
        return None

    start = match.start()
    index = match.end()
    depth = 1
    state = "code"
    quote = ""
    escape = False

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if state == "line_comment":
            if char == "\n":
                state = "code"
        elif state == "block_comment":
            if char == "*" and next_char == "/":
                state = "code"
                index += 1
        elif state == "string":
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == quote:
                state = "code"
                quote = ""
        else:
            if char == "/" and next_char == "/":
                state = "line_comment"
                index += 1
            elif char == "/" and next_char == "*":
                state = "block_comment"
                index += 1
            elif char in ("'", '"', "`"):
                state = "string"
                quote = char
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    if end < len(text) and text[end] == "\r":
                        end += 1
                    if end < len(text) and text[end] == "\n":
                        end += 1
                    return start, end

        index += 1

    return None


def strip_app_block(text: str, app: str) -> tuple[str, bool]:
    bounds = _find_app_block_bounds(text, app)
    if bounds is None:
        return text, False

    start, end = bounds
    block = text[start:end]
    if not any(marker in block for marker in FOREIGN_MARKERS):
        return text, False

    updated = text[:start] + text[end:]
    return updated, True


def strip_slot_ownership(text: str, apps: tuple[str, ...] = APPS) -> tuple[str, list[str]]:
    updated = text
    stripped_apps: list[str] = []

    for app in apps:
        updated, changed = strip_app_block(updated, app)
        if changed:
            stripped_apps.append(app)

    return updated, stripped_apps


def process_paths(paths: list[str]) -> int:
    for raw_path in paths:
        path = Path(raw_path)
        if not path.exists():
            continue

        original = path.read_text(encoding="utf-8")
        updated, stripped_apps = strip_slot_ownership(original)

        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print(
                "Stripped tutor-indigo learner MFE slot ownership from"
                f" {path}: {', '.join(stripped_apps)}"
            )
        else:
            print(f"No tutor-indigo learner MFE slot ownership found in {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(process_paths(sys.argv[1:]))
