#!/usr/bin/env python3
"""
Patch frontend-app-authn source fallbacks so authn stays on the current apps
host for dashboard redirects instead of rebuilding them onto LMS_BASE_URL.
"""

from __future__ import annotations

from dataclasses import dataclass
import sys
from pathlib import Path


SOURCE_SUFFIXES = {".js", ".jsx", ".ts", ".tsx"}


@dataclass(frozen=True)
class PatchSpec:
    name: str
    legacy_path: str
    path_hints: tuple[str, ...]
    original: str
    replacement: str


PATCHES = (
    PatchSpec(
        name="login service dashboard fallback",
        legacy_path="src/login/data/service.js",
        path_hints=("login",),
        original="redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,",
        replacement='redirectUrl: data.redirect_url || "/dashboard",',
    ),
    PatchSpec(
        name="register service dashboard fallback",
        legacy_path="src/register/data/service.js",
        path_hints=("register",),
        original="redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,",
        replacement='redirectUrl: data.redirect_url || "/dashboard",',
    ),
    PatchSpec(
        name="login failure dashboard fallback",
        legacy_path="src/login/LoginFailure.jsx",
        path_hints=("loginfailure",),
        original="const url = `${getConfig().LMS_BASE_URL}/dashboard/?tpa_hint=${context.tpaHint}`;",
        replacement='const url = `/dashboard/?tpa_hint=${context.tpaHint}`;',
    ),
)


@dataclass(frozen=True)
class PatchDecision:
    spec: PatchSpec
    target: Path
    content: str
    already_patched: bool


def iter_source_files(app_dir: Path) -> list[Path]:
    src_dir = app_dir / "src"
    if not src_dir.is_dir():
        raise SystemExit(f"authn source root missing: {src_dir}")

    paths = {
        path
        for path in src_dir.rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES
    }
    for spec in PATCHES:
        legacy_target = app_dir / spec.legacy_path
        if legacy_target.is_file():
            paths.add(legacy_target)

    return sorted(paths)


def load_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def format_paths(paths: list[Path], app_dir: Path) -> str:
    return ", ".join(str(path.relative_to(app_dir)) for path in paths)


def path_matches_spec(path: Path, app_dir: Path, spec: PatchSpec) -> bool:
    relative = str(path.relative_to(app_dir)).replace("\\", "/").lower()
    return all(hint.lower() in relative for hint in spec.path_hints)


def find_decision(app_dir: Path, source_files: list[Path], spec: PatchSpec) -> PatchDecision:
    original_matches: list[tuple[Path, str]] = []
    replacement_matches: list[tuple[Path, str]] = []
    candidate_files = [path for path in source_files if path_matches_spec(path, app_dir, spec)]

    for path in candidate_files:
        content = load_text(path)
        if content is None:
            continue
        if spec.original in content:
            original_matches.append((path, content))
        if spec.replacement in content:
            replacement_matches.append((path, content))

    if len(original_matches) > 1:
        matches = format_paths([path for path, _ in original_matches], app_dir)
        raise SystemExit(f"authn source patch ambiguous for {spec.name}: {matches}")

    if original_matches:
        target, content = original_matches[0]
        return PatchDecision(spec, target, content, already_patched=False)

    if len(replacement_matches) > 1:
        matches = format_paths([path for path, _ in replacement_matches], app_dir)
        raise SystemExit(f"authn source patch already-patched match ambiguous for {spec.name}: {matches}")

    if replacement_matches:
        target, content = replacement_matches[0]
        return PatchDecision(spec, target, content, already_patched=True)

    raise SystemExit(
        f"authn source patch anchor missing for {spec.name}; "
        f"searched {len(candidate_files)} candidate source file(s) under {app_dir / 'src'}"
    )


def patch_app(app_dir: Path) -> int:
    source_files = iter_source_files(app_dir)
    decisions = [find_decision(app_dir, source_files, spec) for spec in PATCHES]

    patched_files = 0
    for decision in decisions:
        if decision.already_patched:
            patched_files += 1
            continue
        decision.target.write_text(
            decision.content.replace(decision.spec.original, decision.spec.replacement),
            encoding="utf-8",
        )
        patched_files += 1
    return patched_files


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: patch-authn-dashboard-fallbacks.py <app_dir>", file=sys.stderr)
        return 2

    app_dir = Path(argv[1])
    if not app_dir.is_dir():
        print(f"app dir not found: {app_dir}", file=sys.stderr)
        return 2

    patched_files = patch_app(app_dir)
    print(f"patched authn dashboard fallbacks ({patched_files} file(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
