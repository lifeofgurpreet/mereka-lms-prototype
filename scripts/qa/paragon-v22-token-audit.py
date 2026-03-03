#!/usr/bin/env python3
"""Generate Paragon v22 token-audit artifacts and documentation."""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]

CORE_THEME_REL = Path("infrastructure/tutor/themes/mereka/mfe/theme/core.min.css")
TOKENS_SCSS_REL = Path("infrastructure/tutor/themes/mereka/scss/_tokens.scss")
DOC_REL = Path("docs/architecture/PARAGON_V22_TOKEN_AUDIT.md")
FULL_MISSING_REL = Path("docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv")
DEFINED_ONLY_REL = Path("docs/architecture/PARAGON_V22_TOKEN_AUDIT_DEFINED_IGNORED.tsv")
CONSUMED_DEFINED_REL = Path("docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_DEFINED.tsv")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Paragon v22 token audit artifacts")
    parser.add_argument("--repo-root", default=str(DEFAULT_REPO_ROOT), help="Repository root")
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write updated markdown and TSV artifacts (default: print summary only)",
    )
    return parser.parse_args()


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_core_consumed_tokens(core_css: str) -> set[str]:
    """Return --pgn-* variables actually consumed by core CSS declarations."""
    # Remove custom-property declaration lines first, so declarations like
    # `--pgn-foo: var(--pgn-bar)` are not counted as consumption.
    without_token_defs = re.sub(r"--pgn-[A-Za-z0-9_-]+\s*:[^;{}]*;", "", core_css)
    return set(re.findall(r"var\(\s*(--pgn-[A-Za-z0-9_-]+)\s*(?:,|\))", without_token_defs))


def parse_defined_tokens(tokens_scss: str) -> set[str]:
    root_match = re.search(r":root\s*\{(.*?)\n\}", tokens_scss, re.S)
    if not root_match:
        return set()
    return set(re.findall(r"(--pgn-[A-Za-z0-9_-]+)\s*:", root_match.group(1)))


def family(token: str) -> str:
    body = token[6:]
    if body.startswith("elevation-box-"):
        return "elevation-box"
    if body.startswith("spacing-spacer-") or body.startswith("spacing-"):
        return "spacing"
    if body.startswith("color-"):
        return "color"
    if body.startswith("typography-"):
        return "typography"
    if body.startswith("size-"):
        return "size"
    if body.startswith("elevation-"):
        return "elevation"
    if body.startswith("transition-"):
        return "transition"
    if body.startswith("btn-"):
        return "button"
    return body.split("-", 1)[0]


def build_family_summary(tokens: set[str]) -> list[tuple[str, int, list[str]]]:
    buckets: dict[str, list[str]] = defaultdict(list)
    for token in sorted(tokens):
        buckets[family(token)].append(token)
    rows = [(name, len(values), values) for name, values in buckets.items()]
    rows.sort(key=lambda item: (-item[1], item[0]))
    return rows


def write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def render_markdown(
    repo_root: Path,
    consumed: set[str],
    defined: set[str],
    consumed_defined: list[str],
    consumed_missing: list[str],
    defined_ignored: list[str],
) -> str:
    generated_on = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    family_summary = build_family_summary(set(consumed_missing))

    lines: list[str] = [
        "# Paragon v22 Token Audit",
        "",
        "## Source",
        f"- Source core theme: `{CORE_THEME_REL}`",
        f"- Theme bridge: `{TOKENS_SCSS_REL}`",
        f"- Generated on: {generated_on} (UTC)",
        "- Command: `python3 scripts/qa/paragon-v22-token-audit.py --write`",
        "",
        "## Method",
        "- Parse `var(--pgn-*)` references from `core.min.css`.",
        "- Remove custom property definition lines first (`--pgn-*:` declarations are excluded).",
        "- Compare consumed set to the `:root` `--pgn-*` definitions in `_tokens.scss`.",
        "- Classify into `consumed+defined`, `consumed+missing`, and `defined+ignored`.",
        "",
        "## Counts",
        f"- Consumed tokens (from `core.min.css`): `{len(consumed)}`",
        f"- Defined in `_tokens.scss`: `{len(defined)}`",
        f"- Consumed & defined: `{len(consumed_defined)}`",
        f"- Consumed & missing: `{len(consumed_missing)}`",
        f"- Defined & ignored: `{len(defined_ignored)}`",
        "",
        "## Consumed & Defined",
        "- These tokens are read by current Paragon styles and already supplied in `_tokens.scss`.",
        "",
    ]
    for token in consumed_defined:
        lines.append(f"- `{token}`")

    lines.extend(
        [
            "",
            "## Consumed & Missing (High-Value Families)",
            "- Full list for actionability is in:",
            f"  - `{FULL_MISSING_REL}`",
            "- Family breakdown:",
            "  - color",
            "  - size",
            "  - spacing",
            "  - typography",
            "  - elevation",
            "  - elevation-box",
            "  - button",
            "  - transition",
            "  - alert",
            "",
            "| Family | Count | Sample tokens |",
            "| --- | ---: | --- |",
        ]
    )

    for name, count, values in family_summary[:12]:
        sample = ", ".join(values[:5])
        lines.append(f"| {name} | {count} | `{sample}`{', ...' if count > 5 else ''} |")

    lines.extend(
        [
            "",
            "## Defined & Ignored",
            "- These tokens are defined in `_tokens.scss` but not observed in the current",
            "  `var()` consumption pass of `core.min.css`.",
            "- Keep only if they are intentionally retained for fallback or future-safe migration.",
            "",
        ]
    )
    for token in defined_ignored:
        lines.append(f"- `{token}`")

    lines.extend(
        [
            "",
            "## Operational Notes",
        "- This is a **consumption audit only**. It intentionally does not infer tokens",
        f"  by scanning declaration names in `{CORE_THEME_REL}`.",
            "- Large full lists are stored in TSV artifacts to support diff-friendly reviews:",
            f"  - `{FULL_MISSING_REL}`",
            f"  - `{DEFINED_ONLY_REL}`",
            f"  - `{CONSUMED_DEFINED_REL}`",
            "",
            "## Guidance for Phase C",
            "- Prioritize replacing BEM overrides only where token replacement is known to take effect.",
            "- For `--pgn-*` tokens in `defined+ignored`, prefer explicit `--mereka-*` overrides in our own CSS.",
            "- Re-audit whenever `core.min.css` changes (Theme URL runtime path update).",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root)

    core_css = read_file(repo_root / CORE_THEME_REL)
    tokens_scss = read_file(repo_root / TOKENS_SCSS_REL)

    consumed = parse_core_consumed_tokens(core_css)
    defined = parse_defined_tokens(tokens_scss)

    consumed_defined = sorted(consumed & defined)
    consumed_missing = sorted(consumed - defined)
    defined_ignored = sorted(defined - consumed)

    if args.write:
        # Keep artifacts in docs/architecture for review and CI checks.
        write_lines(repo_root / CONSUMED_DEFINED_REL, [f"{token}" for token in consumed_defined])
        write_lines(repo_root / FULL_MISSING_REL, [f"{token}" for token in consumed_missing])
        write_lines(repo_root / DEFINED_ONLY_REL, [f"{token}" for token in defined_ignored])
        doc = render_markdown(
            repo_root=repo_root,
            consumed=consumed,
            defined=defined,
            consumed_defined=consumed_defined,
            consumed_missing=consumed_missing,
            defined_ignored=defined_ignored,
        )
        write_lines(repo_root / DOC_REL, doc.splitlines())

    for label, tokens in (
        ("consumed", consumed),
        ("defined", defined),
        ("consumed+defined", consumed_defined),
        ("consumed+missing", consumed_missing),
        ("defined+ignored", defined_ignored),
    ):
        print(f"{label}={len(tokens)}")

    print("Top missing families:")
    for fam_name, count, tokens in build_family_summary(set(consumed_missing))[:8]:
        print(f"- {fam_name}: {count} (example: {tokens[0]})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
