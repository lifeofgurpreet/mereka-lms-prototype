#!/usr/bin/env python3
"""Prune deprecated default-path residue from rendered Tutor MFE artifacts."""

from __future__ import annotations

import re
import sys
from pathlib import Path

APPS = ("orders", "payment")

CANONICAL_APT_HARDENING_BLOCK = (
    "RUN printf '%s\\n' \\\n"
    "    'Acquire::Retries \"6\";' \\\n"
    "    'Acquire::http::Timeout \"30\";' \\\n"
    "    'Acquire::https::Timeout \"30\";' \\\n"
    "    'Acquire::ForceIPv4 \"true\";' \\\n"
    "    > /etc/apt/apt.conf.d/80-retries && \\\n"
    "    apt-get update \\\n"
    "  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing git"
)

UPSTREAM_BASE_APT_BLOCK = (
    "RUN apt update \\\n"
    "  && apt install -y git \\\n"
    "    # required for cwebp-bin\n"
    "    gcc libgl1 libxi6 make \\\n"
    "    # required for gifsicle, mozjpeg, and optipng (on arm)\n"
    "    autoconf libtool pkg-config zlib1g-dev \\\n"
    "    # required for node-sass (on arm)\n"
    "    python g++ \\\n"
    "    # required for image-webpack-loader (on arm)\n"
    "    libpng-dev \\\n"
    "    # required for building node-canvas (on arm, for authoring)\n"
    "    # https://www.npmjs.com/package/canvas\n"
    "    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev"
)

CANONICAL_BASE_APT_BLOCK = (
    "RUN printf '%s\\n' \\\n"
    "    'Acquire::Retries \"6\";' \\\n"
    "    'Acquire::http::Timeout \"30\";' \\\n"
    "    'Acquire::https::Timeout \"30\";' \\\n"
    "    'Acquire::ForceIPv4 \"true\";' \\\n"
    "    > /etc/apt/apt.conf.d/80-retries && \\\n"
    "    apt-get update \\\n"
    "  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing git \\\n"
    "    # required for cwebp-bin\n"
    "    gcc libgl1 libxi6 make \\\n"
    "    # required for gifsicle, mozjpeg, and optipng (on arm)\n"
    "    autoconf libtool pkg-config zlib1g-dev \\\n"
    "    # required for node-sass (on arm)\n"
    "    python3 g++ python3-distutils \\\n"
    "    # required for image-webpack-loader (on arm)\n"
    "    libpng-dev \\\n"
    "    # required for building node-canvas (on arm, for authoring)\n"
    "    # https://www.npmjs.com/package/canvas\n"
    "    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \\\n"
    "  && rm -rf /var/lib/apt/lists/*"
)


def _replace_count(pattern: str, repl: str, text: str) -> tuple[str, int]:
    compiled = re.compile(pattern, re.S | re.M)
    return compiled.subn(repl, text)


def _replace_literal(pattern: str, repl: str, text: str) -> tuple[str, int]:
    compiled = re.compile(pattern, re.S | re.M)
    return compiled.subn(lambda _: repl, text)


def _replace_exact(needle: str, repl: str, text: str) -> tuple[str, int]:
    count = text.count(needle)
    return text.replace(needle, repl), count


def prune_dockerfile(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    total = 0

    text, count = _replace_exact(
        UPSTREAM_BASE_APT_BLOCK,
        CANONICAL_BASE_APT_BLOCK,
        text,
    )
    total += count

    text, count = _replace_literal(
        r"RUN printf 'Acquire::Retries \"5\";\\nAcquire::http::Timeout \"120\";\\n' > /etc/apt/apt\.conf\.d/80-retries && \\\n    apt-get update \\\n  && apt-get install -y --fix-broken git",
        CANONICAL_APT_HARDENING_BLOCK,
        text,
    )
    total += count
    text, count = _replace_literal(
        r"RUN printf 'Acquire::Retries \"5\";\nAcquire::http::Timeout \"120\";\n' > /etc/apt/apt\.conf\.d/80-retries && \\\n    apt-get update \\\n  && apt-get install -y --fix-broken git",
        CANONICAL_APT_HARDENING_BLOCK,
        text,
    )
    total += count
    text, count = _replace_literal(
        r"RUN printf '%s\n' \\\n    'Acquire::Retries \"6\";' \\\n    'Acquire::http::Timeout \"30\";' \\\n    'Acquire::https::Timeout \"30\";' \\\n    'Acquire::ForceIPv4 \"true\";' \\\n    > /etc/apt/apt\.conf\.d/80-retries && \\\n    apt-get update \\\n  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing git",
        CANONICAL_APT_HARDENING_BLOCK,
        text,
    )
    total += count

    for app in APPS:
        text, count = _replace_count(
            rf"\n####################### {app} MFE.*?(?=\n####################### [a-z0-9-]+ MFE|\n# Production images are last to accelerate dev image building)",
            "\n",
            text,
        )
        total += count
        text, count = _replace_count(
            rf"\n######## {app} \(production\).*?(?=\n######## [a-z0-9-]+ \(production\)|\n####### final production image with all static assets)",
            "\n",
            text,
        )
        total += count
        text, count = _replace_count(
            rf"\nCOPY --from={app}-prod /openedx/app/dist /openedx/dist/{app}\n",
            "\n",
            text,
        )
        total += count

    text, count = _replace_count(
        r"\nARG ENABLE_NEW_RELIC=false\nENV ENABLE_NEW_RELIC=\$\{ENABLE_NEW_RELIC\}\n",
        "\n",
        text,
    )
    total += count
    text, count = _replace_count(
        r"\nARG ENABLE_NEW_RELIC=false\n",
        "\n",
        text,
    )
    total += count
    text, count = _replace_count(
        r"\n# Set cookie domains for MFE builds\nARG SESSION_COOKIE_DOMAIN=[^\n]*\nARG CSRF_COOKIE_DOMAIN=[^\n]*\nENV SESSION_COOKIE_DOMAIN=\$\{SESSION_COOKIE_DOMAIN\}\nENV CSRF_COOKIE_DOMAIN=\$\{CSRF_COOKIE_DOMAIN\}\n",
        "\n",
        text,
    )
    total += count
    text, count = _replace_count(
        r"\nARG SESSION_COOKIE_DOMAIN=[^\n]*\nARG CSRF_COOKIE_DOMAIN=[^\n]*\nENV SESSION_COOKIE_DOMAIN=\$\{SESSION_COOKIE_DOMAIN\}\nENV CSRF_COOKIE_DOMAIN=\$\{CSRF_COOKIE_DOMAIN\}\n",
        "\n",
        text,
    )
    total += count
    text, count = _replace_count(
        r"\nRUN npm install '@edx/brand@github:@edly-io/brand-openedx#indigo-2\.5\.0'\n",
        "\n",
        text,
    )
    total += count

    if total:
        path.write_text(text, encoding="utf-8")
    return total


def prune_caddyfile(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    total = 0

    for app in APPS:
        text, count = _replace_count(
            rf"\n\s*@mfe_{app} \{{.*?\n\s*\}}\n\s*handle @mfe_{app} \{{.*?\n\s*\}}\n",
            "\n",
            text,
        )
        total += count

    if total:
        path.write_text(text, encoding="utf-8")
    return total


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: mfe_prune_deprecated_shells.py <dockerfile> <caddyfile>", file=sys.stderr)
        return 2

    dockerfile = Path(argv[1])
    caddyfile = Path(argv[2])
    if not dockerfile.is_file():
        print(f"dockerfile not found: {dockerfile}", file=sys.stderr)
        return 2
    if not caddyfile.is_file():
        print(f"caddyfile not found: {caddyfile}", file=sys.stderr)
        return 2

    dockerfile_changes = prune_dockerfile(dockerfile)
    caddyfile_changes = prune_caddyfile(caddyfile)

    if dockerfile_changes == 0 and caddyfile_changes == 0:
        print("default-path MFE residue already pruned")
        return 0

    print(
        "pruned default-path MFE residue "
        f"(dockerfile sections: {dockerfile_changes}, caddyfile sections: {caddyfile_changes})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
