#!/usr/bin/env bash
# Patch: Webpack memory limit increase and build optimizations.
# Sets NODE_OPTIONS=--max-old-space-size=6144, REQUIRE_BUILD_PROFILE_OPTIMIZE=none,
# TerserPlugin parallel:false, removes requireCompatConfig.

apply_webpack_memory_patch() {
  local targets=(
    "$OPENEDX_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile"
    "$WEBPACK_PROD_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/edx-platform/webpack.prod.config.js"
  )

  "${PYTHON_BIN}" - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # ENV block normalization and NODE_OPTIONS / PYTHONPATH / REQUIRE_BUILD_PROFILE_OPTIMIZE
    env_block_spaces = "ENV PATH /openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV /openedx/venv/\nWORKDIR /openedx/edx-platform\n"
    env_block_equals = "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\nWORKDIR /openedx/edx-platform\n"
    env_block_short = "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\n"
    env_replacement = "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\nENV PYTHONPATH=/openedx/edx-platform\nENV NODE_OPTIONS=\"--max-old-space-size=6144\"\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\nWORKDIR /openedx/edx-platform\n"
    updated = updated.replace(env_block_spaces, env_replacement)
    updated = updated.replace(env_block_equals, env_replacement)
    updated = updated.replace(
        env_block_short,
        "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\nENV PYTHONPATH=/openedx/edx-platform\nENV NODE_OPTIONS=\"--max-old-space-size=6144\"\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n",
    )
    updated = updated.replace('ENV NODE_OPTIONS="--max-old-space-size=1536"\n', "")
    while "ENV PYTHONPATH=/openedx/edx-platform\nENV PYTHONPATH=/openedx/edx-platform\n" in updated:
        updated = updated.replace(
            "ENV PYTHONPATH=/openedx/edx-platform\nENV PYTHONPATH=/openedx/edx-platform\n",
            "ENV PYTHONPATH=/openedx/edx-platform\n",
        )
    dup_suffix = "ENV PYTHONPATH=/openedx/edx-platform\nENV NODE_OPTIONS=\"--max-old-space-size=6144\"\n"
    while env_replacement + dup_suffix in updated:
        updated = updated.replace(env_replacement + dup_suffix, env_replacement)
    while dup_suffix + dup_suffix in updated:
        updated = updated.replace(dup_suffix + dup_suffix, dup_suffix)
    updated = updated.replace('ENV NODE_OPTIONS="--max-old-space-size=4096"\n', "")
    updated = updated.replace(
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH=/openedx/edx-platform\nENV COMPREHENSIVE_THEME_DIRS',
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV COMPREHENSIVE_THEME_DIRS',
    )

    # Fix collectstatic uglify-js parse error by disabling RequireJS r.js minification
    updated = updated.replace(
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH="/openedx/edx-platform"\n',
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH="/openedx/edx-platform"\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n',
    )
    env_trio_unquoted = (
        'ENV PYTHONPATH=/openedx/edx-platform\n'
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\n'
        'ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n'
    )
    env_trio_quoted = (
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\n'
        'ENV PYTHONPATH="/openedx/edx-platform"\n'
        'ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n'
    )
    updated = re.sub(rf"(?:{re.escape(env_trio_unquoted)})+", env_trio_unquoted, updated)
    updated = re.sub(rf"(?:{re.escape(env_trio_quoted)})+", env_trio_quoted, updated)
    while "ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n" in updated:
        updated = updated.replace(
            "ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n",
            "ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n",
        )

    # Webpack config patches
    updated = updated.replace(
        "new TerserPlugin(),",
        "new TerserPlugin({ parallel: false }),",
    )
    updated = updated.replace(
        "module.exports = [..._.values(optimizedConfig), ..._.values(requireCompatConfig)];",
        "module.exports = [..._.values(optimizedConfig)];",
    )

    if updated != original:
        path.write_text(updated)
PY
}
