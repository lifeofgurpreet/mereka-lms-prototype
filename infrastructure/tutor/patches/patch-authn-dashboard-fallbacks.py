#!/usr/bin/env python3
"""
Patch frontend-app-authn source fallbacks so authn stays on the current apps
host for dashboard redirects instead of rebuilding them onto LMS_BASE_URL.
"""

from __future__ import annotations

import sys
from pathlib import Path


PATCHES = (
    (
        "src/login/data/service.js",
        "redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,",
        'redirectUrl: data.redirect_url || "/dashboard",',
    ),
    (
        "src/register/data/service.js",
        "redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,",
        'redirectUrl: data.redirect_url || "/dashboard",',
    ),
    (
        "src/login/LoginFailure.jsx",
        "const url = `${getConfig().LMS_BASE_URL}/dashboard/?tpa_hint=${context.tpaHint}`;",
        'const url = `/dashboard/?tpa_hint=${context.tpaHint}`;',
    ),
)


def patch_app(app_dir: Path) -> int:
    patched_files = 0
    for relative_path, original, replacement in PATCHES:
        target = app_dir / relative_path
        if not target.exists():
            raise SystemExit(f"authn source patch target missing: {target}")

        content = target.read_text(encoding="utf-8")
        if replacement in content:
            patched_files += 1
            continue
        if original not in content:
            raise SystemExit(f"authn source patch anchor missing in {target}")

        target.write_text(content.replace(original, replacement), encoding="utf-8")
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
