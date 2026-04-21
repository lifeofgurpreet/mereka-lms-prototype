#!/usr/bin/env bash
# test-mfe-prune-deprecated-shells.sh - fixture tests for MFE prune helper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - <<'PY' "$REPO_ROOT"
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

repo_root = Path(sys.argv[1])
patch = repo_root / "infrastructure/tutor/patches/mfe_prune_deprecated_shells.py"


def load_patch_module():
    spec = importlib.util.spec_from_file_location("mfe_prune_deprecated_shells", patch)
    if spec is None or spec.loader is None:
        raise AssertionError(f"could not load {patch}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_contains(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def assert_not_contains(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


module = load_patch_module()
with tempfile.TemporaryDirectory(prefix="mfe-prune-test.") as raw_tmp:
    tmp = Path(raw_tmp)
    dockerfile = tmp / "Dockerfile"
    caddyfile = tmp / "Caddyfile"

    dockerfile.write_text(
        "\n".join(
            [
                "FROM node:24",
                module.UPSTREAM_BASE_APT_BLOCK,
                "####################### orders MFE",
                "RUN echo build orders",
                "####################### profile MFE",
                "RUN echo keep profile",
                "######## orders (production)",
                "RUN echo orders production",
                "######## profile (production)",
                "RUN echo keep profile production",
                "COPY --from=orders-prod /openedx/app/dist /openedx/dist/orders",
                "ARG ENABLE_NEW_RELIC=false",
                "ENV ENABLE_NEW_RELIC=${ENABLE_NEW_RELIC}",
                "# Set cookie domains for MFE builds",
                "ARG SESSION_COOKIE_DOMAIN=.localhost",
                "ARG CSRF_COOKIE_DOMAIN=.localhost",
                "ENV SESSION_COOKIE_DOMAIN=${SESSION_COOKIE_DOMAIN}",
                "ENV CSRF_COOKIE_DOMAIN=${CSRF_COOKIE_DOMAIN}",
                "RUN npm install '@edx/brand@github:@edly-io/brand-openedx#indigo-2.5.0'",
                "# Production images are last to accelerate dev image building",
                "RUN echo done",
                "",
            ]
        ),
        encoding="utf-8",
    )
    caddyfile.write_text(
        """

@mfe_orders {
    path /orders /orders/*
}
handle @mfe_orders {
    root * /openedx/dist/orders
}
@mfe_profile {
    path /profile /profile/*
}
handle @mfe_profile {
    root * /openedx/dist/profile
}
""",
            encoding="utf-8",
        )

    first = subprocess.run(
        [sys.executable, str(patch), str(dockerfile), str(caddyfile)],
        check=False,
        capture_output=True,
        text=True,
    )
    if first.returncode != 0:
        raise AssertionError(first.stderr or first.stdout)

    patched_dockerfile = dockerfile.read_text(encoding="utf-8")
    patched_caddyfile = caddyfile.read_text(encoding="utf-8")
    assert_contains(patched_dockerfile, 'Acquire::ForceIPv4 "true";', "apt retry hardening")
    assert_contains(patched_dockerfile, "python3-distutils", "Python 3 apt dependency")
    assert_contains(patched_dockerfile, "####################### profile MFE", "non-deprecated MFE section")
    assert_not_contains(patched_dockerfile, "####################### orders MFE", "orders build section")
    assert_not_contains(patched_dockerfile, "######## orders (production)", "orders production section")
    assert_not_contains(patched_dockerfile, "COPY --from=orders-prod", "orders final copy")
    assert_not_contains(patched_dockerfile, "ARG ENABLE_NEW_RELIC=false", "New Relic arg residue")
    assert_not_contains(patched_dockerfile, "SESSION_COOKIE_DOMAIN", "cookie domain residue")
    assert_not_contains(patched_dockerfile, "brand-openedx#indigo-2.5.0", "legacy brand install")
    assert_not_contains(patched_caddyfile, "@mfe_orders", "orders Caddy matcher")
    assert_contains(patched_caddyfile, "@mfe_profile", "unrelated Caddy matcher")

    after_first_dockerfile = patched_dockerfile
    after_first_caddyfile = patched_caddyfile
    second = subprocess.run(
        [sys.executable, str(patch), str(dockerfile), str(caddyfile)],
        check=False,
        capture_output=True,
        text=True,
    )
    if second.returncode != 0:
        raise AssertionError(second.stderr or second.stdout)
    if dockerfile.read_text(encoding="utf-8") != after_first_dockerfile:
        raise AssertionError("Dockerfile changed on second prune run")
    if caddyfile.read_text(encoding="utf-8") != after_first_caddyfile:
        raise AssertionError("Caddyfile changed on second prune run")

print("PASS: mfe_prune_deprecated_shells fixtures passed")
PY
