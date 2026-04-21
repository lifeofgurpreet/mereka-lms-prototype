#!/usr/bin/env bash
# Patch: residual rendered-file normalization for Tutor 21.x (Ulmo).
# Scope: Open edX Dockerfile text replacements that remain patch-owned:
#        production-stage fast-profile translation preflight/wrappers.
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

PRODUCTION_TRANSLATION_ANCHOR = "# Pull latest translations via atlas\n"
PRODUCTION_BUILD_PROFILE_ARG = "ARG MEREKA_BUILD_PROFILE=proof\n"
TRANSLATION_SETTINGS_PREFLIGHT = (
    'RUN if [ "$MEREKA_BUILD_PROFILE" = "fast" ]; then '
    'echo "Skipping translation settings import preflight (fast build profile)"; '
    "else "
    "python -c 'import importlib, os; "
    "os.environ.setdefault(\"DJANGO_SETTINGS_MODULE\", \"lms.envs.tutor.i18n\"); "
    "importlib.import_module(\"lms.envs.tutor.i18n\"); "
    "print(\"translation settings import preflight ok\")'; "
    "fi\n"
)
TRANSLATION_REFRESH = (
    'RUN if [ "$MEREKA_BUILD_PROFILE" = "fast" ]; then '
    'echo "Skipping translation refresh (fast build profile)"; '
    "else make clean_translations; fi\n"
)
STALE_TRANSLATION_PREFLIGHTS = (
    "RUN python - <<'PY'\n"
    "import importlib\n"
    "import os\n\n"
    "os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.tutor.i18n')\n"
    "importlib.import_module('lms.envs.tutor.i18n')\n"
    "print('translation settings import preflight ok')\n"
    "PY\n",
    "RUN if [ \\\"$MEREKA_BUILD_PROFILE\\\" = \\\"fast\\\" ]; then "
    "echo \\\"Skipping translation settings import preflight (fast build profile)\\\"; "
    "else "
    "python -c \\\"import importlib, os; "
    "os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.tutor.i18n'); "
    "importlib.import_module('lms.envs.tutor.i18n'); "
    "print('translation settings import preflight ok')\\\"; "
    "fi\n",
)
TRANSLATION_REFRESH_VARIANTS = (
    "RUN make clean_translations\n",
    TRANSLATION_REFRESH,
)
ADVANCED_XBLOCKS_PRODUCTION_COPY = (
    "# Carry openedx_advanced_xblocks into production before translation and\n"
    "# XBlock entry-point discovery. Its install metadata already lives in the\n"
    "# venv from python-requirements, but the source tree must also exist in\n"
    "# this stage before pull_plugin_translations / compile_xblock_translations.\n"
    "COPY --from=python-requirements --chown=app:app "
    "/openedx/openedx_advanced_xblocks /openedx/openedx_advanced_xblocks\n"
)
BASE_ASSETS_INSTALL = (
    "RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,"
    "target=/openedx/edx-platform/requirements/edx/base.txt \\\n"
    "    --mount=type=bind,from=edx-platform,source=/requirements/edx/assets.txt,"
    "target=/openedx/edx-platform/requirements/edx/assets.txt \\\n"
    "    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\\n"
    "    $PIP_COMMAND install -r /openedx/edx-platform/requirements/edx/base.txt "
    "-r /openedx/edx-platform/requirements/edx/assets.txt"
)
BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL = BASE_ASSETS_INSTALL.replace(
    "$PIP_COMMAND install -r",
    "$PIP_COMMAND install --no-build-isolation -r",
)
UWSGI_UV_INSTALL = "$PIP_COMMAND install --no-cache-dir --compile uwsgi==2.0.24"
UWSGI_PIP_INSTALL = "pip install --no-cache-dir --no-build-isolation uwsgi==2.0.24"


def wrap_translation_step(text: str, pattern: str, builder) -> str:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        return text
    return text.replace(match.group(0), builder(match), 1)


def normalize_translation_header(text: str) -> str:
    if PRODUCTION_TRANSLATION_ANCHOR not in text:
        return text
    updated = text.replace(
        PRODUCTION_TRANSLATION_ANCHOR + PRODUCTION_BUILD_PROFILE_ARG,
        PRODUCTION_TRANSLATION_ANCHOR,
    )
    for stale in (*STALE_TRANSLATION_PREFLIGHTS, TRANSLATION_SETTINGS_PREFLIGHT):
        updated = updated.replace(stale, "")
    for refresh in TRANSLATION_REFRESH_VARIANTS:
        updated = updated.replace(refresh, "")
    return updated.replace(
        PRODUCTION_TRANSLATION_ANCHOR,
        (
            PRODUCTION_TRANSLATION_ANCHOR
            + PRODUCTION_BUILD_PROFILE_ARG
            + TRANSLATION_SETTINGS_PREFLIGHT
            + TRANSLATION_REFRESH
        ),
        1,
    )


def ensure_advanced_xblocks_source_before_translations(text: str) -> str:
    if ADVANCED_XBLOCKS_PRODUCTION_COPY in text:
        return text
    marker = "RUN $PIP_COMMAND install -e .\n"
    if marker not in text or "pull_plugin_translations" not in text:
        return text
    return text.replace(
        marker,
        marker + "\n" + ADVANCED_XBLOCKS_PRODUCTION_COPY,
        1,
    )

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

    updated = updated.replace(BASE_ASSETS_INSTALL, BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL)
    updated = updated.replace(UWSGI_UV_INSTALL, UWSGI_PIP_INSTALL)
    updated = normalize_translation_header(updated)
    updated = ensure_advanced_xblocks_source_before_translations(updated)
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
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compile_xblock_translations\n"
        "RUN ./manage.py cms --settings=tutor.i18n compile_xblock_translations\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
        "echo \"Skipping XBlock translation compile (fast build profile)\"; "
        "else ./manage.py lms --settings=tutor.i18n compile_xblock_translations && "
        "./manage.py cms --settings=tutor.i18n compile_xblock_translations; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compile_plugin_translations\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
        "echo \"Skipping compile_plugin_translations (fast build profile)\"; "
        "else ./manage.py lms --settings=tutor.i18n compile_plugin_translations; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilemessages -v1\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
        "echo \"Skipping compilemessages (fast build profile)\"; "
        "else ./manage.py lms --settings=tutor.i18n compilemessages -v1; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n\n"
        "RUN ./manage.py cms --settings=tutor.i18n compilejsi18n\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then "
        "mkdir -p /openedx/staticfiles/js/i18n /openedx/staticfiles/studio/js/i18n && "
        "echo \"Skipping compilejsi18n (fast build profile)\"; "
        "else ./manage.py lms --settings=tutor.i18n compilejsi18n "
        "--output /openedx/staticfiles/js/i18n && "
        "./manage.py cms --settings=tutor.i18n compilejsi18n "
        "--output /openedx/staticfiles/studio/js/i18n; fi\n",
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
