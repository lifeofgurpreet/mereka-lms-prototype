#!/usr/bin/env bash
# Patch: Webpack memory limit increase and build optimizations.
# Sets NODE_OPTIONS=--max-old-space-size=6144, REQUIRE_BUILD_PROFILE_OPTIMIZE=none,
# TerserPlugin parallel:false, removes requireCompatConfig.

apply_webpack_memory_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local targets=(
    "$OPENEDX_TEMPLATE"
    "$tutor_root/env/build/openedx/Dockerfile"
    "$WEBPACK_PROD_TEMPLATE"
    "$tutor_root/env/build/openedx/edx-platform/webpack.prod.config.js"
  )

  "${PYTHON_BIN}" - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import sys

targets = sys.argv[1:]

# The canonical ENV trio we want present (unquoted form, Tutor 21 / Ulmo style).
# This is the authoritative value; all dedup logic targets this exact string.
ENV_TRIO = (
    'ENV PYTHONPATH=/openedx/edx-platform\n'
    'ENV NODE_OPTIONS="--max-old-space-size=6144"\n'
    'ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n'
)

# The PATH+VIRTUAL_ENV anchor that should precede the trio in the assets build stage.
ENV_ANCHOR_SHORT = (
    'ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\n'
    'ENV VIRTUAL_ENV=/openedx/venv/\n'
)

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # ── Step 1: Normalise legacy spacing / WORKDIR-inline variants ──────────
    # These only appear when the template is very old or was hand-edited.
    # Replace the space-separated (pre-Tutor-19) form with the equals form.
    updated = updated.replace(
        'ENV PATH /openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\n'
        'ENV VIRTUAL_ENV /openedx/venv/\n'
        'WORKDIR /openedx/edx-platform\n',
        ENV_ANCHOR_SHORT + 'WORKDIR /openedx/edx-platform\n',
    )
    # Replace equals+WORKDIR-inline form (old rendered Dockerfile variant).
    updated = updated.replace(
        ENV_ANCHOR_SHORT + 'WORKDIR /openedx/edx-platform\n',
        ENV_ANCHOR_SHORT,
    )

    # ── Step 2: Inject trio if the anchor exists but trio is missing ─────────
    # Sentinel check: only inject when the line immediately after VIRTUAL_ENV
    # is NOT already the PYTHONPATH line.  This makes the replacement idempotent
    # regardless of how many times apply-patches.sh is run.
    anchor_with_trio = ENV_ANCHOR_SHORT + ENV_TRIO
    if ENV_ANCHOR_SHORT in updated and anchor_with_trio not in updated:
        updated = updated.replace(ENV_ANCHOR_SHORT, ENV_ANCHOR_SHORT + ENV_TRIO, 1)

    # ── Step 3: Collapse duplicate trio blocks (any count → exactly one) ─────
    # Handles accumulated duplicates from previous broken runs.  A single re.sub
    # with a + quantifier collapses N consecutive copies to 1 regardless of N.
    updated = re.sub(
        r'(?:' + re.escape(ENV_TRIO) + r')+',
        ENV_TRIO,
        updated,
    )

    # ── Step 4: Remove stale NODE_OPTIONS lines left by older patch variants ──
    updated = updated.replace('ENV NODE_OPTIONS="--max-old-space-size=1536"\n', '')
    updated = updated.replace('ENV NODE_OPTIONS="--max-old-space-size=4096"\n', '')

    # ── Step 5: Remove orphaned PYTHONPATH that trailed NODE_OPTIONS earlier ──
    # Old patch inserted: NODE_OPTIONS … PYTHONPATH … COMPREHENSIVE_THEME_DIRS.
    # Tutor 21 already has PYTHONPATH before NODE_OPTIONS, so the trailing one
    # was a stray duplicate.  Strip it only when it directly precedes COMPREHENSIVE.
    updated = updated.replace(
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH=/openedx/edx-platform\nENV COMPREHENSIVE_THEME_DIRS',
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV COMPREHENSIVE_THEME_DIRS',
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
