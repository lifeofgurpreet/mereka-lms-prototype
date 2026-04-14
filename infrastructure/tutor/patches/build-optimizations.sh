#!/usr/bin/env bash
# Patch: residual rendered-file normalization for Tutor 21.x (Ulmo).
# Scope: Open edX Dockerfile text replacements that remain patch-owned:
#        fast-profile translation pull wrappers.
#        Build-context file sync now lives in apply-patches.sh.

apply_build_optimizations_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local targets=(
    "$tutor_root/env/build/openedx/Dockerfile"
  )

  "${PYTHON_BIN}" - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import sys

targets = sys.argv[1:]


def wrap_translation_step(text: str, pattern: str, builder) -> str:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        return text
    return text.replace(match.group(0), builder(match), 1)

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # ── openedx Dockerfile patches ──────────────────────────────────────

    # Keep uwsgi on plain pip for now: a local uv preflight against uwsgi==2.0.24
    # still fails in wheel build with C compiler errors around signal handler
    # signatures. Treat this as an explicit compatibility exception, not a
    # forgotten uv seam.

    updated = wrap_translation_step(
        updated,
        r"RUN \./manage\.py lms --settings=tutor\.i18n pull_plugin_translations --verbose --repository='openedx/openedx-translations' --revision='(?P<revision>[^']+)'[ \t]*\n",
        lambda match: (
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
            "echo \"Skipping plugin translation pull (fast build profile)\"; "
            "else ./manage.py lms --settings=tutor.i18n pull_plugin_translations "
            "--verbose --repository='openedx/openedx-translations' "
            f"--revision='{match.group('revision')}'; fi\n"
        ),
    )
    updated = wrap_translation_step(
        updated,
        r"RUN \./manage\.py lms --settings=tutor\.i18n pull_xblock_translations --repository='openedx/openedx-translations' --revision='(?P<revision>[^']+)'[ \t]*\n",
        lambda match: (
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
            "echo \"Skipping XBlock translation pull (fast build profile)\"; "
            "else ./manage.py lms --settings=tutor.i18n pull_xblock_translations "
            "--repository='openedx/openedx-translations' "
            f"--revision='{match.group('revision')}'; fi\n"
        ),
    )
    updated = wrap_translation_step(
        updated,
        r"RUN atlas pull --repository='openedx/openedx-translations' --revision='(?P<revision>[^']+)'  \\\n"
        r"    translations/edx-platform/conf/locale:conf/locale \\\n"
        r"    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend\n",
        lambda match: (
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
            "echo \"Skipping atlas translation pull (fast build profile)\"; "
            "else atlas pull --repository='openedx/openedx-translations' "
            f"--revision='{match.group('revision')}'  \\\n"
            "    translations/edx-platform/conf/locale:conf/locale \\\n"
            "    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend; fi\n"
        ),
    )
    # REMOVED: Redwood-era node_modules COPY path fixes + node cache reuse (FROM overhangio/openedx:18.2.2)
    # This was a Tutor 18/Redwood optimization that copied node_modules from the upstream
    # Redwood image. Incompatible with Ulmo (different node version, package structure).
    # Tutor 21's standard node install with BuildKit cache is the correct approach.

    # ── Network resilience for ARC DinD runners ───────────────────────
    # ARC container runners have flaky outbound networking (gnutls_handshake
    # failures, connection timeouts).  Wrap git-clone and apt-get in retry
    # loops so transient failures don't kill 30-minute builds.

    # REMOVED: Tutor v21 node_modules path fix (was lines 277-282)
    # This `mv` moved node_modules to /openedx/node_modules but the production stage
    # COPY still referenced /openedx/edx-platform/node_modules → build failure.
    # Upstream Tutor 21 fixed the paths natively. Do not re-add.

    # ── assets.py patches ───────────────────────────────────────────────

    if updated != original:
        path.write_text(updated)
PY
}
