#!/usr/bin/env bash
# Patch: Build optimizations and openedx Dockerfile/settings patches.
# Target: Tutor 21.x (Ulmo). Some replacements target Redwood-era template
# patterns and are harmless no-ops on Ulmo (str.replace returns unchanged text).
# Covers: pip retries, compile-sass, collectstatic fixes, i18n fixes,
#         custom apps, django settings (discussions, theme, oauth fix,
#         tenancy), assets.py (JS_COMPRESSOR, safe_join), MFE cache headers,
#         nginx health/profile endpoints, Caddy profile proxy.

apply_build_optimizations_patch() {
  local targets=(
    "$OPENEDX_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile"
    "$MYSQL_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/local/docker-compose.yml"
    "$LMS_SETTINGS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
    "$LMS_ASSETS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/settings/lms/assets.py"
    "$CMS_ASSETS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/settings/cms/assets.py"
    "$NGINX_LMS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf"
    "$CADDY_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile"
  )

  "${PYTHON_BIN}" - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import textwrap
import sys

targets = sys.argv[1:]

STATIC_PAYLOAD_TRIM_BLOCK = textwrap.dedent(
    """\
    RUN rm -rf /openedx/staticfiles/stylelint-config-edx \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/node_modules \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/README* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/package* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/openedx*.yaml \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/babel.config* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/renovate* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/LICENSE* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/build/*.scss \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/build/*/*.stories.* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/build/*/_storybook-styles* \\
               /openedx/staticfiles/frontend-component-cookie-policy-banner/build/setupTest* \\
               /openedx/staticfiles/edx-bootstrap/README* \\
               /openedx/staticfiles/edx-bootstrap/stylelint.config* \\
               /openedx/staticfiles/edx-bootstrap/postcss.config* \\
               /openedx/staticfiles/edx-bootstrap/Makefile* \\
               /openedx/staticfiles/edx-bootstrap/package* \\
               /openedx/staticfiles/edx-bootstrap/samples \\
               /openedx/staticfiles/edx-bootstrap/node_modules"""
)

FINAL_RUNTIME_PRUNE_BLOCK = textwrap.dedent(
    """\
    RUN rm -rf /opt/pyenv/.github \\
               /opt/pyenv/test \\
               /opt/pyenv/src \\
               /opt/pyenv/man \\
               /opt/pyenv/completions \\
               /opt/pyenv/terminal_output.png \\
               /opt/pyenv/versions/3.11.8/bin/pip \\
               /opt/pyenv/versions/3.11.8/bin/pip3 \\
               /opt/pyenv/versions/3.11.8/bin/pip3.11 \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/test \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/__pycache__ \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/idlelib \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/tkinter \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/turtledemo \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip-24.0.dist-info \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/libpython3.11.a \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Makefile \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.bootstrap \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.local \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.stdlib \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/install-sh \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/makesetup \\
               /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/python.o \\
               /openedx/venv/bin/pip \\
               /openedx/venv/bin/pip3 \\
               /openedx/venv/bin/pip3.11 \\
               /openedx/venv/lib/python3.11/site-packages/pip \\
               /openedx/venv/lib/python3.11/site-packages/pip-24.0.dist-info \\
               /openedx/venv/lib/python3.11/site-packages/wheel \\
               /openedx/venv/lib/python3.11/site-packages/wheel-0.45.1.dist-info"""
)

STATIC_PAYLOAD_TRIM_RE = re.compile(
    r"RUN rm -rf /openedx/staticfiles/stylelint-config-edx \\\n"
    r"(?:\s+/openedx/staticfiles/[^\n]+(?: \\\n|\n))+",
    re.MULTILINE,
)

FINAL_RUNTIME_PRUNE_RE = re.compile(
    r"RUN rm -rf /opt/pyenv/\.github \\\n"
    r"(?:\s+/(?:opt/pyenv|openedx/venv)[^\n]+(?: \\\n|\n))+",
    re.MULTILINE,
)


def normalize_single_block(text: str, marker: str, pattern: re.Pattern[str], canonical_block: str) -> str:
    if marker not in text:
        return text
    normalized = pattern.sub(canonical_block + "\n", text)
    if normalized == text:
        return text
    return normalized

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # ── openedx Dockerfile patches ──────────────────────────────────────

    # MySQL 8.4 removed default_authentication_plugin. Keep the local Tutor
    # compose authority aligned with the repo-owned MySQL contract.
    updated = updated.replace(
        "--default-authentication-plugin=mysql_native_password",
        "--mysql-native-password=ON",
    )

    # i18n archive URL fix
    updated = updated.replace(
        "https://github.com/openedx/openedx-i18n/archive/",
        "https://github.com/openedx-unsupported/openedx-i18n/archive/",
    )
    updated = updated.replace(
        "ARG OPENEDX_I18N_VERSION=open-release/redwood.master",
        "ARG OPENEDX_I18N_VERSION=master",
    )
    updated = updated.replace(
        "ARG OPENEDX_I18N_VERSION={{ OPENEDX_COMMON_VERSION }}",
        "ARG OPENEDX_I18N_VERSION=master",
    )
    old_code_stage_pin_block = textwrap.dedent(
        """\
        # Align compiled base requirements with the realized Python 3.11 compatibility contract.
        RUN python3 - <<'PY'
        from pathlib import Path

        base_txt = Path("/openedx/edx-platform/requirements/edx/base.txt")
        text = base_txt.read_text()
        replacements = {
            "django-cors-headers==4.9.0": "django-cors-headers==4.3.1",
            "edx-enterprise==6.5.1": "edx-enterprise==6.6.9",
            "lxml-html-clean==0.4.3": "lxml-html-clean==0.4.4",
            "path==16.11.0": "path==16.16.0",
        }
        for old, new in replacements.items():
            if old in text:
                text = text.replace(old, new)
        base_txt.write_text(text)
        PY"""
    )
    rejected_code_stage_pin_block = textwrap.dedent(
        """\
        # Align compiled base requirements with the realized Python 3.11 compatibility contract.
        RUN sed -i \\
            -e 's/django-cors-headers==4.9.0/django-cors-headers==4.3.1/g' \\
            -e 's/edx-enterprise==6.5.1/edx-enterprise==6.6.9/g' \\
            -e 's/lxml-html-clean==0.4.3/lxml-html-clean==0.4.4/g' \\
            -e 's/path==16.11.0/path==16.16.0/g' \\
            /openedx/edx-platform/requirements/edx/base.txt"""
    )
    updated = updated.replace(old_code_stage_pin_block, "")
    updated = updated.replace(rejected_code_stage_pin_block, "")
    updated = updated.replace("\n\n\n# Identify tutor user to apply patches using git", "\n\n# Identify tutor user to apply patches using git")

    # uv pip / no-build-isolation fixes
    updated = updated.replace(
        "$PIP_COMMAND install -r /openedx/edx-platform/requirements/edx/base.txt -r /openedx/edx-platform/requirements/edx/assets.txt",
        "$PIP_COMMAND install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt -r /openedx/edx-platform/requirements/edx/assets.txt",
    )
    updated = updated.replace(
        "([ -s /tmp/base-filtered.txt ] && pip install --no-build-isolation -r /tmp/base-filtered.txt -r /tmp/assets.txt || pip install --no-build-isolation -r /tmp/assets.txt) && \\\n"
        "    ([ -s /tmp/git-packages.txt ] && xargs -r -a /tmp/git-packages.txt pip install --no-build-isolation || true)",
        "([ -s /tmp/base-filtered.txt ] && $PIP_COMMAND install --no-build-isolation -r /tmp/base-filtered.txt -r /tmp/assets.txt || $PIP_COMMAND install --no-build-isolation -r /tmp/assets.txt) && \\\n"
        "    ([ -s /tmp/git-packages.txt ] && xargs -r -a /tmp/git-packages.txt $PIP_COMMAND install --no-build-isolation || true)",
    )
    updated = updated.replace(
        "$PIP_COMMAND install -r requirements/edx/development.txt",
        "$PIP_COMMAND install --no-build-isolation -r requirements/edx/development.txt",
    )
    updated = updated.replace(
        "RUN pip install setuptools==44.1.0 pip==20.0.2 wheel==0.34.2",
        "RUN pip install --upgrade pip==25.0.1 setuptools==75.3.0 wheel==0.45.1",
    )
    updated = updated.replace(
        "setuptools==69.1.1 setuptools-scm==8.1.0 pip==24.0 wheel==0.43.0",
        "setuptools==69.1.1 setuptools-scm==8.1.0 pip==24.0 wheel==0.43.0 pkgconfig==1.5.5",
    )
    updated = re.sub(
        r"(setuptools==69\.1\.1 setuptools-scm==8\.1\.0 pip==24\.0 wheel==0\.43\.0)(?: pkgconfig==1\.5\.5)+",
        r"\1 pkgconfig==1.5.5",
        updated,
    )
    updated = re.sub(
        r"(?: pkgconfig==1\.5\.5){2,}",
        " pkgconfig==1.5.5",
        updated,
    )
    # Keep uwsgi on plain pip for now: a local uv preflight against uwsgi==2.0.24
    # still fails in wheel build with C compiler errors around signal handler
    # signatures. Treat this as an explicit compatibility exception, not a
    # forgotten uv seam.
    updated = updated.replace(
        '$PIP_COMMAND install --no-cache-dir --compile uwsgi==2.0.24',
        'pip install --no-cache-dir --no-build-isolation uwsgi==2.0.24',
    )
    updated = updated.replace(
        'RUN pip install "ora2==7.0.0"',
        'RUN $PIP_COMMAND install "ora2==7.0.0"',
    )

    # pip install retry wrapping
    updated = updated.replace(
        "RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\\n    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\\n    pip install -r /openedx/edx-platform/requirements/edx/base.txt",
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do $PIP_COMMAND install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "$PIP_COMMAND install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
    )
    updated = updated.replace(
        "RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\\n    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\\n    bash -o pipefail -c 'for attempt in 1 2 3; do \\n        pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0 \\n        echo \"pip install attempt ${attempt} failed; retrying in 10s\" >&2 \\n        sleep 10 \\n    done; exit 1'",
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do $PIP_COMMAND install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "$PIP_COMMAND install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
    )
    updated = updated.replace(
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do
        pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0
        echo "pip install attempt ${attempt} failed; retrying in 10s" >&2
        sleep 10
    done; exit 1'""",
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do $PIP_COMMAND install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "$PIP_COMMAND install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
    )

    # Local requirements removal
    updated = updated.replace(
        "# Re-install local requirements, otherwise egg-info folders are missing\nRUN pip install -r requirements/edx/local.in\n\n",
        "# Local requirements list removed in Redwood; skip redundant reinstall step.\n",
    )

    # coursewarehistoryextended + optional apps
    updated = updated.replace(
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\n',
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\n# Mereka adjustments keep Redwood optional apps enabled\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\nif "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]\nif "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]\nif "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]\nif "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.theming.apps.ThemingConfig\"]\n',
    )

    # compilemessages fix
    updated = updated.replace(
        "RUN cd /openedx/locale/user && \\\n    django-admin.py compilemessages -v1",
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/python -m django compilemessages -v1",
    )
    updated = updated.replace(
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/django-admin.py compilemessages -v1",
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/python -m django compilemessages -v1",
    )
    build_profile_arg = "ARG MEREKA_BUILD_PROFILE=proof\n"
    custom_app_install_mode_arg = "ARG MEREKA_CUSTOM_APP_INSTALL_MODE=editable\n"
    if build_profile_arg not in updated and custom_app_install_mode_arg in updated:
        updated = updated.replace(
            custom_app_install_mode_arg,
            build_profile_arg + custom_app_install_mode_arg,
            1,
        )

    legacy_translation_preflight_block = (
        "RUN python - <<'PY'\n"
        "import importlib\n"
        "import os\n\n"
        "os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.tutor.i18n')\n"
        "importlib.import_module('lms.envs.tutor.i18n')\n"
        "print('translation settings import preflight ok')\n"
        "PY\n"
    )
    translation_preflight_block = (
        'RUN if [ "$MEREKA_BUILD_PROFILE" = "fast" ]; then '
        'echo "Skipping translation settings import preflight (fast build profile)"; '
        "else "
        "python -c 'import importlib, os; "
        "os.environ.setdefault(\"DJANGO_SETTINGS_MODULE\", \"lms.envs.tutor.i18n\"); "
        "importlib.import_module(\"lms.envs.tutor.i18n\"); "
        "print(\"translation settings import preflight ok\")'; "
        "fi\n"
    )
    escaped_translation_preflight_block = (
        "RUN if [ \\\"$MEREKA_BUILD_PROFILE\\\" = \\\"fast\\\" ]; then "
        "echo \\\"Skipping translation settings import preflight (fast build profile)\\\"; "
        "else "
        "python -c \\\"import importlib, os; "
        "os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.tutor.i18n'); "
        "importlib.import_module('lms.envs.tutor.i18n'); "
        "print('translation settings import preflight ok')\\\"; "
        "fi\n"
    )
    updated = updated.replace(legacy_translation_preflight_block, "")
    updated = updated.replace(escaped_translation_preflight_block, translation_preflight_block)
    if f"{build_profile_arg}{translation_preflight_block}" not in updated and translation_preflight_block in updated:
        updated = updated.replace(
            translation_preflight_block,
            build_profile_arg + translation_preflight_block,
            1,
        )
    updated = updated.replace(
        "RUN make clean_translations",
        f"{translation_preflight_block}RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping translation refresh (fast build profile)\"; else make clean_translations; fi",
    )
    updated = re.sub(
        rf"(?:{re.escape(translation_preflight_block)})+RUN make clean_translations",
        f"{translation_preflight_block}RUN make clean_translations",
        updated,
    )
    updated = re.sub(
        rf"(?:{re.escape(translation_preflight_block)}){{2,}}",
        translation_preflight_block,
        updated,
    )

    # compilejsi18n
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n\nRUN ./manage.py cms --settings=tutor.i18n compilejsi18n\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then mkdir -p /openedx/staticfiles/js/i18n /openedx/staticfiles/studio/js/i18n && echo \"Skipping compilejsi18n (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n && ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n\nRUN ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then mkdir -p /openedx/staticfiles/js/i18n /openedx/staticfiles/studio/js/i18n && echo \"Skipping compilejsi18n (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n && ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n; fi\n",
    )
    updated = updated.replace(
        "# Redwood skips manual compilejsi18n while content libraries mature.\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then mkdir -p /openedx/staticfiles/js/i18n /openedx/staticfiles/studio/js/i18n && echo \"Skipping compilejsi18n (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n && ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n pull_plugin_translations --verbose --repository='openedx/openedx-translations' --revision='release/ulmo.1' ",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping plugin translation pull (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n pull_plugin_translations --verbose --repository='openedx/openedx-translations' --revision='release/ulmo.1'; fi",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n pull_xblock_translations --repository='openedx/openedx-translations' --revision='release/ulmo.1' \n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping XBlock translation pull (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n pull_xblock_translations --repository='openedx/openedx-translations' --revision='release/ulmo.1'; fi\n",
    )
    updated = updated.replace(
        "RUN atlas pull --repository='openedx/openedx-translations' --revision='release/ulmo.1'  \\\n    translations/edx-platform/conf/locale:conf/locale \\\n    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping atlas translation pull (fast build profile)\"; else atlas pull --repository='openedx/openedx-translations' --revision='release/ulmo.1'  \\\n    translations/edx-platform/conf/locale:conf/locale \\\n    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compile_xblock_translations\nRUN ./manage.py cms --settings=tutor.i18n compile_xblock_translations\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping XBlock translation compile (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compile_xblock_translations && ./manage.py cms --settings=tutor.i18n compile_xblock_translations; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compile_plugin_translations\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping compile_plugin_translations (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compile_plugin_translations; fi\n",
    )
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilemessages -v1\n",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping compilemessages (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n compilemessages -v1; fi\n",
    )

    # REMOVED: Redwood-era node_modules COPY path fixes + node cache reuse (FROM overhangio/openedx:18.2.2)
    # This was a Tutor 18/Redwood optimization that copied node_modules from the upstream
    # Redwood image. Incompatible with Ulmo (different node version, package structure).
    # Tutor 21's standard node install with BuildKit cache is the correct approach.

    updated = updated.replace("fonts\\\\.googleapis\\\\.com", "fonts[.]googleapis[.]com")

    # edx-platform cherry-pick removal
    patch_block = """# Patch edx-platform
# edx-proctoring security fix https://github.com/edx/edx-platform/pull/29347/
RUN git fetch --depth=2 https://github.com/edx/edx-platform d61dcac29d1651956623c150be53a8bbe69e9346 \\
  && git cherry-pick d61dcac29d1651956623c150be53a8bbe69e9346
# Fix "from" address in course bulk emails
# https://github.com/edx/edx-platform/pull/29001
RUN git fetch --depth=4 https://github.com/bitmakerla/edx-platform 6b0e9f50e9425d17cd62d1b3e9d1cab220e3fe7f \\
  && git cherry-pick 01216d9e0637a2260b4c264bda2f22c1e34b38de \\
  && git cherry-pick a057853a85560759d1d922b00db110207252c6a2 \\
  && git cherry-pick 6b0e9f50e9425d17cd62d1b3e9d1cab220e3fe7f




"""
    updated = updated.replace(
        patch_block,
        "# Patch edx-platform\n# Redwood already bundles the required security/email fixes; cherry-picks disabled locally.\n\n",
    )

    # ── Network resilience for ARC DinD runners ───────────────────────
    # ARC container runners have flaky outbound networking (gnutls_handshake
    # failures, connection timeouts).  Wrap git-clone and apt-get in retry
    # loops so transient failures don't kill 30-minute builds.

    # pyenv download: replace git clone with curl tarball download.
    # ARC DinD containers have broken gnutls (git+HTTPS fails consistently).
    # curl uses OpenSSL, not gnutls, so it works where git doesn't.
    if path.name == "Dockerfile":
        plain_pyenv = "RUN git clone https://github.com/pyenv/pyenv $PYENV_ROOT --branch v2.3.36 --depth 1"
        curl_pyenv = (
            "RUN mkdir -p $PYENV_ROOT && \\\n"
            "    for attempt in 1 2 3 4 5; do \\\n"
            "      curl -fsSL --retry 5 --retry-delay 10 \\\n"
            "        https://github.com/pyenv/pyenv/archive/refs/tags/v2.3.36.tar.gz \\\n"
            "        | tar xz --strip-components=1 -C $PYENV_ROOT && break; \\\n"
            '      echo "pyenv download attempt $attempt failed; retrying in 15s" >&2; \\\n'
            "      rm -rf $PYENV_ROOT/*; \\\n"
            "      sleep 15; \\\n"
            "    done && test -x \"$PYENV_ROOT/bin/pyenv\""
        )
        # Also handle the retry version from a previous patch
        retry_pyenv_marker = "pyenv clone attempt"
        if plain_pyenv in updated:
            updated = updated.replace(plain_pyenv, curl_pyenv)
        elif retry_pyenv_marker in updated:
            # Replace the retry-git-clone version with curl version
            import re as _re
            updated = _re.sub(
                r"RUN for attempt in 1 2 3 4 5; do \\\n"
                r"      git clone https://github\.com/pyenv/pyenv \$PYENV_ROOT --branch v2\.3\.36 --depth 1 && break; \\\n"
                r'      echo "pyenv clone attempt \$attempt failed; retrying in 15s" >&2; \\\n'
                r"      rm -rf \$PYENV_ROOT; \\\n"
                r"      sleep 15; \\\n"
                r'    done && test -d "\$PYENV_ROOT/bin"',
                curl_pyenv,
                updated,
            )

    # REMOVED: Tutor v21 node_modules path fix (was lines 277-282)
    # This `mv` moved node_modules to /openedx/node_modules but the production stage
    # COPY still referenced /openedx/edx-platform/node_modules → build failure.
    # Upstream Tutor 21 fixed the paths natively. Do not re-add.

    # mereka-overrides.css bake into staticfiles
    if path.name == "Dockerfile" and "rdfind -makesymlinks" in updated and "mereka-overrides.css" not in updated:
        rdfind_marker = "rdfind -makesymlinks true -followsymlinks true /openedx/staticfiles/"
        css_copy = (
            "rdfind -makesymlinks true -followsymlinks true /openedx/staticfiles/\n\n"
            "# Ensure mereka theme CSS + logo images are baked into staticfiles.\n"
            "# collectstatic with tutor.assets settings may not pick these up via\n"
            "# ThemeFileSystemFinder when COMPREHENSIVE_THEME_DIRS is only an ENV var.\n"
            "# static.url() in production (ProductionStorage) strips the theme-name prefix,\n"
            "# so files land in staticfiles/css/ and staticfiles/images/ (not staticfiles/mereka/).\n"
            "RUN mkdir -p /openedx/staticfiles/css /openedx/staticfiles/images && \\\n"
            "    cp -f /openedx/themes/mereka/lms/static/css/mereka-overrides.css \\\n"
            "       /openedx/staticfiles/css/mereka-overrides.css || true && \\\n"
            "    cp -f /openedx/themes/mereka/cms/static/css/mereka-overrides.css \\\n"
            "       /openedx/staticfiles/css/mereka-overrides.css 2>/dev/null || true && \\\n"
            "    for img in logo-horizontal.png logo-horizontal.svg \\\n"
            "               logo-horizontal-white.png logo-horizontal-white.svg \\\n"
            "               logo-square.png logo-square.svg logo.png; do \\\n"
            "      cp -f /openedx/themes/mereka/lms/static/images/$img \\\n"
            "         /openedx/staticfiles/images/$img 2>/dev/null || true; \\\n"
            "    done && \\\n"
            "    for hashed in /openedx/staticfiles/images/logo.*.png; do \\\n"
            "      [ -f \"$hashed\" ] && cp -f /openedx/themes/mereka/lms/static/images/logo.png \"$hashed\" 2>/dev/null || true; \\\n"
            "    done"
        )
        updated = updated.replace(rdfind_marker, css_copy)
    if path.name == "Dockerfile" and "RUN rm -rf /openedx/staticfiles/stylelint-config-edx" not in updated:
        updated = updated.replace(
            "    for hashed in /openedx/staticfiles/images/logo.*.png; do \\\n"
            "      [ -f \"$hashed\" ] && cp -f /openedx/themes/mereka/lms/static/images/logo.png \"$hashed\" 2>/dev/null || true; \\\n"
            "    done",
            "    for hashed in /openedx/staticfiles/images/logo.*.png; do \\\n"
            "      [ -f \"$hashed\" ] && cp -f /openedx/themes/mereka/lms/static/images/logo.png \"$hashed\" 2>/dev/null || true; \\\n"
            f"    done\n{STATIC_PAYLOAD_TRIM_BLOCK}",
        )
    if path.name == "Dockerfile":
        updated = normalize_single_block(
            updated,
            "RUN rm -rf /openedx/staticfiles/stylelint-config-edx",
            STATIC_PAYLOAD_TRIM_RE,
            STATIC_PAYLOAD_TRIM_BLOCK,
        )

    if path.name == "Dockerfile":
        updated = updated.replace(
            'if [ "$MEREKA_BUILD_PROFILE" = "fast" ]; then echo "Skipping rdfind static dedupe (fast build profile)"; else rdfind -makesymlinks true -followsymlinks true /openedx/staticfiles/; fi',
            "rdfind -makesymlinks true -followsymlinks true /openedx/staticfiles/",
        )
        final_stage_legacy = """###### Final image with production cmd
FROM production AS final

# Default amount of uWSGI processes
ENV UWSGI_WORKERS=2

# Copy the default uWSGI configuration
COPY --chown=app:app settings/uwsgi.ini /openedx

# Run server
CMD ["uwsgi", "/openedx/uwsgi.ini"]
"""
        final_stage_minimal = """###### Final image with production cmd
FROM minimal AS final

ARG APP_USER_ID=1000

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \\
    --mount=type=cache,target=/var/lib/apt,sharing=locked \\
    apt update \\
    && apt install -y gettext gfortran graphviz graphviz-dev libffi-dev libfreetype6-dev libgeos-dev libjpeg8-dev liblapack-dev libmysqlclient-dev libpng-dev libsqlite3-dev libxmlsec1-dev lynx mysql-client ntp pkg-config

RUN if [ "$APP_USER_ID" = 0 ]; then echo "app user may not be root" && false; fi
RUN useradd --no-log-init --home-dir /openedx --create-home --shell /bin/bash --uid ${APP_USER_ID} app
USER ${APP_USER_ID}

COPY --link --from=docker.io/powerman/dockerize:0.19.0 /usr/local/bin/dockerize /usr/local/bin/dockerize
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/edx-platform /openedx/edx-platform
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=python /opt/pyenv /opt/pyenv
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=python-requirements /openedx/venv /openedx/venv
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /mnt /mnt
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/bin /openedx/bin
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/config /openedx/config
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/themes /openedx/themes
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/staticfiles /openedx/staticfiles
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/data /openedx/data

RUN rm -rf /opt/pyenv/.github \\
           /opt/pyenv/test \\
           /opt/pyenv/src \\
           /opt/pyenv/man \\
           /opt/pyenv/completions \\
           /opt/pyenv/terminal_output.png \\
           /opt/pyenv/versions/3.11.8/bin/pip \\
           /opt/pyenv/versions/3.11.8/bin/pip3 \\
           /opt/pyenv/versions/3.11.8/bin/pip3.11 \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/test \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/__pycache__ \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/idlelib \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/tkinter \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/turtledemo \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip-24.0.dist-info \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/libpython3.11.a \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Makefile \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.bootstrap \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.local \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/Setup.stdlib \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/install-sh \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/makesetup \\
           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/python.o \\
           /openedx/venv/bin/pip \\
           /openedx/venv/bin/pip3 \\
           /openedx/venv/bin/pip3.11 \\
           /openedx/venv/lib/python3.11/site-packages/pip \\
           /openedx/venv/lib/python3.11/site-packages/pip-24.0.dist-info \\
           /openedx/venv/lib/python3.11/site-packages/wheel \\
           /openedx/venv/lib/python3.11/site-packages/wheel-0.45.1.dist-info

ENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}
ENV VIRTUAL_ENV=/openedx/venv/
ENV PYTHONPATH=/openedx/edx-platform
ENV COMPREHENSIVE_THEME_DIRS=/openedx/themes
ENV STATIC_ROOT_LMS=/openedx/staticfiles
ENV STATIC_ROOT_CMS=/openedx/staticfiles/studio
ENV SERVICE_VARIANT=lms
ENV DJANGO_SETTINGS_MODULE=lms.envs.tutor.production
ENV UWSGI_WORKERS=2

# Copy the default uWSGI configuration
COPY --chown=app:app settings/uwsgi.ini /openedx

# Run server
CMD ["uwsgi", "/openedx/uwsgi.ini"]
"""
        final_stage_runtime = """FROM production AS runtime-edx-platform-pruned

RUN rm -rf /openedx/edx-platform/.git \\
           /openedx/edx-platform/.github \\
           /openedx/edx-platform/docs \\
           /openedx/edx-platform/test_root \\
           /openedx/edx-platform/results.txt

###### Final image with production cmd
FROM docker.io/ubuntu:22.04 AS final

ARG APP_USER_ID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \\
    --mount=type=cache,target=/var/lib/apt,sharing=locked \\
    apt update \\
    && apt install -y --no-install-recommends \\
        ca-certificates \\
        curl \\
        gettext-base \\
        graphviz \\
        libffi8 \\
        libfreetype6 \\
        libgeos-c1v5 \\
        libjpeg-turbo8 \\
        liblapack3 \\
        default-mysql-client \\
        libmysqlclient21 \\
        libpng16-16 \\
        libsqlite3-0 \\
        libxml2 \\
        libxmlsec1 \\
        libxmlsec1-openssl \\
        libxslt1.1 \\
        locales \\
        xmlsec1 \\
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$APP_USER_ID" = 0 ]; then echo "app user may not be root" && false; fi
RUN useradd --no-log-init --home-dir /openedx --create-home --shell /bin/bash --uid ${APP_USER_ID} app
USER ${APP_USER_ID}

COPY --link --from=docker.io/powerman/dockerize:0.19.0 /usr/local/bin/dockerize /usr/local/bin/dockerize
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=runtime-edx-platform-pruned /openedx/edx-platform /openedx/edx-platform
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=python /opt/pyenv /opt/pyenv
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=python-requirements /openedx/venv /openedx/venv
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /mnt /mnt
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/bin /openedx/bin
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/config /openedx/config
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/themes /openedx/themes
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/staticfiles /openedx/staticfiles
COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/data /openedx/data

ENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}
ENV VIRTUAL_ENV=/openedx/venv/
ENV PYTHONPATH=/openedx/edx-platform
ENV COMPREHENSIVE_THEME_DIRS=/openedx/themes
ENV STATIC_ROOT_LMS=/openedx/staticfiles
ENV STATIC_ROOT_CMS=/openedx/staticfiles/studio
ENV SERVICE_VARIANT=lms
ENV DJANGO_SETTINGS_MODULE=lms.envs.tutor.production
ENV UWSGI_WORKERS=2

# Copy the default uWSGI configuration
COPY --chown=app:app settings/uwsgi.ini /openedx

# Run server
CMD ["uwsgi", "/openedx/uwsgi.ini"]
"""
        updated = updated.replace(final_stage_legacy, final_stage_runtime)
        updated = updated.replace(final_stage_minimal, final_stage_runtime)
        if "FROM production AS runtime-edx-platform-pruned" not in updated and "###### Final image with production cmd\nFROM docker.io/ubuntu:22.04 AS final\n" in updated:
            updated = updated.replace(
                "###### Final image with production cmd\nFROM docker.io/ubuntu:22.04 AS final\n",
                "FROM production AS runtime-edx-platform-pruned\n\nRUN rm -rf /openedx/edx-platform/.git \\\n"
                "           /openedx/edx-platform/.github \\\n"
                "           /openedx/edx-platform/docs \\\n"
                "           /openedx/edx-platform/test_root \\\n"
                "           /openedx/edx-platform/results.txt\n\n"
                "###### Final image with production cmd\nFROM docker.io/ubuntu:22.04 AS final\n",
                1,
            )
        updated = updated.replace(
            "FROM docker.io/ubuntu:22.04 AS final\n\nARG APP_USER_ID=1000\n\nENV DEBIAN_FRONTEND=noninteractive\nENV LC_ALL=en_US.UTF-8\n",
            "FROM docker.io/ubuntu:22.04 AS final\n\nARG APP_USER_ID=1000\n\nENV DEBIAN_FRONTEND=noninteractive\nENV LANG=C.UTF-8\nENV LC_ALL=C.UTF-8\n",
        )
        updated = updated.replace(
            "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/edx-platform /openedx/edx-platform",
            "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=runtime-edx-platform-pruned /openedx/edx-platform /openedx/edx-platform",
        )
        updated = updated.replace(
            "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/data /openedx/data\n\nENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}\n",
            "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=production /openedx/data /openedx/data\n\n"
            f"{FINAL_RUNTIME_PRUNE_BLOCK}\n\n"
            "ENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}\n",
        )
        updated = updated.replace(
            "           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/python.o\n\nENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}\n",
            "           /opt/pyenv/versions/3.11.8/lib/python3.11/config-3.11-x86_64-linux-gnu/python.o \\\n"
            "           /opt/pyenv/versions/3.11.8/bin/pip \\\n"
            "           /opt/pyenv/versions/3.11.8/bin/pip3 \\\n"
            "           /opt/pyenv/versions/3.11.8/bin/pip3.11 \\\n"
            "           /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip \\\n"
            "           /opt/pyenv/versions/3.11.8/lib/python3.11/site-packages/pip-24.0.dist-info \\\n"
            "           /openedx/venv/bin/pip \\\n"
            "           /openedx/venv/bin/pip3 \\\n"
            "           /openedx/venv/bin/pip3.11 \\\n"
            "           /openedx/venv/lib/python3.11/site-packages/pip \\\n"
            "           /openedx/venv/lib/python3.11/site-packages/pip-24.0.dist-info \\\n"
            "           /openedx/venv/lib/python3.11/site-packages/wheel \\\n"
            "           /openedx/venv/lib/python3.11/site-packages/wheel-0.45.1.dist-info\n\n"
            "ENV PATH=/openedx/venv/bin:/openedx/bin:${PATH}\n",
        )
        updated = normalize_single_block(
            updated,
            "RUN rm -rf /opt/pyenv/.github",
            FINAL_RUNTIME_PRUNE_RE,
            FINAL_RUNTIME_PRUNE_BLOCK,
        )

    # Remove duplicate production-stage custom app reinjection. These apps are
    # already installed in python-requirements, and the final runtime contract
    # is now gated by MEREKA_CUSTOM_APP_INSTALL_MODE instead of a second
    # production-stage editable-install fan-out.
    if path.name == "Dockerfile" and "/openedx/edx-platform" in updated:
        legacy_code_stage_custom_apps_pattern = re.compile(
            r"\n# Copy custom apps\n"
            r"COPY --chown=app:app \./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix\n"
            r"COPY --chown=app:app \./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus\n"
            r"COPY --chown=app:app \./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/mfe_oauth_fix\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/openedx_prometheus\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/plugins/mereka_tenancy\n"
            r"\n# Add repository roots to Python path via \.pth file for proper module imports\.\n"
            r"# Include /openedx because custom app packages are mounted there as top-level Django apps\.\n"
            r"RUN python3 -c \"import sysconfig; open\(sysconfig.get_path\('purelib'\) \+ '/mereka-plugins\.pth', 'w'\)\.write\('/openedx\\n/openedx/plugins\\n'\)\"\n",
            re.MULTILINE,
        )
        updated, _ = legacy_code_stage_custom_apps_pattern.subn("\n", updated, count=1)

        production_custom_apps_pattern = re.compile(
            r"\n# Copy custom apps\n"
            r"COPY --chown=app:app \./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix\n"
            r"COPY --chown=app:app \./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus\n"
            r"COPY --chown=app:app \./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/mfe_oauth_fix\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/openedx_prometheus\n"
            r"RUN (?:uv pip install|pip install) -e /openedx/plugins/mereka_tenancy\n"
            r"(?:\n#.*)*\n"
            r"RUN (?:.*mereka-plugins\.pth\"|echo '/openedx/plugins' > /openedx/venv/lib/python3\.11/site-packages/mereka-plugins\.pth)\n",
            re.MULTILINE,
        )
        updated, _ = production_custom_apps_pattern.subn("\n", updated, count=1)

        # django-prometheus pip install in Dockerfile
        base_req_marker = "bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo \"pip install attempt ${attempt} failed; retrying in 10s\" >&2; sleep 10; done; exit 1'"
        if base_req_marker in updated:
            if "django-prometheus" not in updated:
                prometheus_install = base_req_marker + """\n\n# Install django-prometheus for metrics
RUN uv pip install django-prometheus==2.3.1"""
                updated = updated.replace(base_req_marker, prometheus_install)

        advanced_xblocks_marker = "RUN $PIP_COMMAND install -e .\n"
        advanced_xblocks_copy = (
            "RUN $PIP_COMMAND install -e .\n\n"
            "# Carry openedx_advanced_xblocks into production before translation and\n"
            "# XBlock entry-point discovery. Its install metadata already lives\n"
            "# in the venv from python-requirements, but the source tree must also exist\n"
            "# in this stage before pull_plugin_translations / compile_xblock_translations.\n"
            "COPY --from=python-requirements --chown=app:app /openedx/openedx_advanced_xblocks /openedx/openedx_advanced_xblocks\n"
        )
        if (
            "pull_plugin_translations" in updated
            and "COPY --from=python-requirements --chown=app:app /openedx/openedx_advanced_xblocks /openedx/openedx_advanced_xblocks" not in updated
            and advanced_xblocks_marker in updated
        ):
            updated = updated.replace(advanced_xblocks_marker, advanced_xblocks_copy, 1)

    # ── production.py patches ───────────────────────────────────────────

    if path.name == "production.py":
        def force_mfe_discussions_only(text):
            if "lms/production.py" not in str(path):
                return text
            if "# Force MFE-only discussions (greenfield" in text:
                return text
            marker = 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = True'
            if marker not in text:
                marker = 'FEATURES["ENABLE_DISCUSSION_SERVICE"] = False'
            if marker not in text:
                return text
            mfe_config = textwrap.dedent("""

            # Force MFE-only discussions (greenfield - no legacy views needed)
            FEATURES["ENABLE_DISCUSSION_HOME_PANEL"] = False  # Disable legacy in-LMS panel

            # Ensure all courses use MFE by default
            DISCUSSIONS_MFE_ENABLED = True
            if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
                _mfe_base = globals().get("MEREKA_MFE_BASE_URL", "https://apps.academyv2.mereka.io")
                DISCUSSIONS_MICROFRONTEND_URL = f"{_mfe_base}/discussions"
            if "DISCUSSIONS_MFE_FEEDBACK_URL" not in globals():
                DISCUSSIONS_MFE_FEEDBACK_URL = None
            """)
            lines = text.splitlines()
            last_idx = None
            for idx, line in enumerate(lines):
                if marker in line and not line.strip().startswith("#"):
                    last_idx = idx
            if last_idx is not None:
                lines.insert(last_idx + 1, mfe_config)
                return "\n".join(lines)
            return text

        updated = force_mfe_discussions_only(updated)

        # Strip the legacy runtime-settings cluster that used to inject default
        # theme + MFE OAuth + Prometheus + tenancy directly into rendered Tutor
        # settings. Source authority for this contract now lives in the
        # consolidated mereka_lms plugin stack.
        legacy_runtime_cluster = re.compile(
            r"# MFE OAuth Fix - Custom app to fix OAuth provider visibility\n"
            r".*?"
            r"MIDDLEWARE\.append\('mereka_tenancy\.middleware\.TenantResolutionMiddleware'\)",
            re.MULTILINE | re.DOTALL,
        )
        updated, _ = legacy_runtime_cluster.subn("\n", updated, count=1)
        theme_marker = '\n# Set default theme for all sites\nDEFAULT_SITE_THEME = "mereka"\n'
        first_theme = updated.find(theme_marker)
        last_theme = updated.rfind(theme_marker)
        if first_theme != -1 and last_theme != -1 and first_theme != last_theme:
            updated = updated[:last_theme] + updated[last_theme + len(theme_marker):]

    # ── assets.py patches ───────────────────────────────────────────────

    if path.name == "assets.py" and "derive_settings" in updated:
        # Ensure optional apps exist when collecting assets (Redwood-era, harmless no-op on Ulmo)
        updated = updated.replace(
            "derive_settings(__name__)\n\nLOCALE_PATHS.append(\"/openedx/locale/contrib/locale\")\n",
            "derive_settings(__name__)\n\n# Ensure optional Redwood apps exist when collecting assets\nif \"openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig\"]\nif \"openedx.core.djangoapps.bookmarks.apps.BookmarksConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.bookmarks.apps.BookmarksConfig\"]\nif \"openedx.core.djangoapps.discussions.apps.DiscussionsConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.discussions.apps.DiscussionsConfig\"]\nif \"openedx.core.djangoapps.theming.apps.ThemingConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.theming.apps.ThemingConfig\"]\n\nLOCALE_PATHS.append(\"/openedx/locale/contrib/locale\")\n",
        )

        # Disable django-pipeline UglifyJS compression
        pipeline_patch = "PIPELINE['JS_COMPRESSOR'] = None\n"
        if "JS_COMPRESSOR" not in updated:
            updated = updated.rstrip() + "\n\n" + pipeline_patch

        # Fix collectstatic SuspiciousFileOperation
        safe_join_patch = (
            "# Monkey-patch safe_join to be permissive during asset build.\n"
            "import sys as _sys\n"
            "import os.path as _osp\n"
            "import django.utils._os as _os_mod\n"
            "_orig_safe_join = _os_mod.safe_join\n"
            "def _build_safe_join(base, *paths):\n"
            "    return _osp.abspath(_osp.join(base, *paths))\n"
            "_os_mod.safe_join = _build_safe_join\n"
            "for _m in list(_sys.modules.values()):\n"
            "    try:\n"
            "        if getattr(_m, 'safe_join', None) is _orig_safe_join:\n"
            "            _m.safe_join = _build_safe_join\n"
            "    except Exception:\n"
            "        pass\n"
        )
        if "_build_safe_join" not in updated:
            updated = updated.rstrip() + "\n\n" + safe_join_patch

    # ── lms.conf patches ────────────────────────────────────────────────

    if path.name == "lms.conf":
        # /health endpoint
        if "location = /health" not in updated:
            health_block = (
                "  location = /health {\n"
                "    default_type text/plain;\n"
                "    return 200 \"ok\\n\";\n"
                "  }\n\n"
            )
            marker = "  location / {"
            if marker in updated:
                updated = updated.replace(marker, health_block + marker, 1)

        # /profile/api/ proxy
        if "apps.academyv2.mereka.io" in updated and "/profile/api/" not in updated:
            pattern = re.compile(
                r"(server_name apps\.academyv2\.mereka\.io;.*?)(\n  location / \{)",
                re.S,
            )
            profile_proxy = (
                "  location ^~ /profile/api/ {\n"
                "    proxy_set_header Host $http_host;\n"
                "    proxy_redirect off;\n"
                "    proxy_pass http://lms-backend;\n"
                "  }\n\n"
            )
            updated = pattern.sub(rf"\\1\n{profile_proxy}\\2", updated, count=1)

    # ── Caddyfile patches ───────────────────────────────────────────────

    if path.name == "Caddyfile":
        # MFE cache headers
        if "apps.academyv2.mereka.io" in updated:
            if "Cache-Control" not in updated or "no-cache" not in updated:
                needle = "apps.academyv2.mereka.io {"
                if needle in updated:
                    cache_config = """    # MFE cache headers to prevent stale blank pages (mereka-lms-2pne)
    header {
        # HTML: no-cache to prevent stale pages after deployment
        @html {
            path *.html /
        }
        Cache-Control "no-cache, no-store, must-revalidate" @html

        # JS/CSS with content-hash: long cache + immutable
        @static {
            path *.js *.css *.woff2 *.woff *.ttf *.eot *.svg *.png *.jpg *.jpeg *.gif *.ico
        }
        Cache-Control "public, max-age=31536000, immutable" @static
    }

"""
                    updated = updated.replace(needle, needle + "\n" + cache_config)

        # /profile/api/ proxy in Caddy
        if "apps.academyv2.mereka.io" in updated and "/profile/api/" not in updated:
            needle = "apps.academyv2.mereka.io {\n        reverse_proxy nginx:80"
            replacement = (
                "apps.academyv2.mereka.io {\n"
                "        reverse_proxy /profile/api/* lms:8000 {\n"
                "            header_up Host {http.request.host}\n"
                "        }\n"
                "        reverse_proxy nginx:80"
            )
            updated = updated.replace(needle, replacement, 1)

    if updated != original:
        path.write_text(updated)
PY

  # ── File sync operations ────────────────────────────────────────────

  # Sync logo files from theme source to build directory
  echo "Syncing logo files from theme source to build directory..."
  local THEME_BUILD_DIR="$REPO_ROOT/tutor_env/env/build/openedx/themes/mereka"
  if [ -d "$THEME_BUILD_DIR" ]; then
    if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images" ]; then
      rm -rf "$THEME_BUILD_DIR/lms/static/images"
      mkdir -p "$THEME_BUILD_DIR/lms/static/images"
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images/." "$THEME_BUILD_DIR/lms/static/images/"
      echo "  Mirrored LMS theme images"
    fi

    if [ -d "$THEME_BUILD_DIR/cms" ]; then
      if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images" ]; then
        rm -rf "$THEME_BUILD_DIR/cms/static/images"
        mkdir -p "$THEME_BUILD_DIR/cms/static/images"
        cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images/." "$THEME_BUILD_DIR/cms/static/images/"
        echo "  Mirrored CMS theme images"
      fi
    fi
    echo "Logo files synced successfully."

    # Copy font assets
    echo "Syncing font files from theme source to build directory..."
    if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts" ]; then
      rm -rf "$THEME_BUILD_DIR/lms/static/fonts"
      mkdir -p "$THEME_BUILD_DIR/lms/static/fonts"
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts/." "$THEME_BUILD_DIR/lms/static/fonts/"
      echo "  Mirrored LMS theme fonts"
    else
      echo "  No LMS fonts found to copy"
    fi

    if [ -d "$THEME_BUILD_DIR/cms" ]; then
      if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts" ]; then
        rm -rf "$THEME_BUILD_DIR/cms/static/fonts"
        mkdir -p "$THEME_BUILD_DIR/cms/static/fonts"
        cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts/." "$THEME_BUILD_DIR/cms/static/fonts/"
        echo "  Mirrored CMS theme fonts"
      else
        echo "  No CMS fonts found to copy"
      fi
    fi

    # Sync theme templates/static overrides
    echo "Syncing theme templates/static overrides to build directory..."
    rm -rf \
      "$THEME_BUILD_DIR/common/templates" \
      "$THEME_BUILD_DIR/common/static/css" \
      "$THEME_BUILD_DIR/lms/templates" \
      "$THEME_BUILD_DIR/lms/static/css"
    mkdir -p "$THEME_BUILD_DIR/common/templates" "$THEME_BUILD_DIR/common/static/css"
    mkdir -p "$THEME_BUILD_DIR/lms/templates" "$THEME_BUILD_DIR/lms/static/css"
    cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/." "$THEME_BUILD_DIR/lms/templates/"
    if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css" ]; then
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/." "$THEME_BUILD_DIR/lms/static/css/"
    fi
    if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates" ]; then
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates/." "$THEME_BUILD_DIR/common/templates/"
    fi
    if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css" ]; then
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/." "$THEME_BUILD_DIR/common/static/css/"
    fi
    if [ -d "$THEME_BUILD_DIR/cms" ]; then
      rm -rf \
        "$THEME_BUILD_DIR/cms/templates" \
        "$THEME_BUILD_DIR/cms/static/css" \
        "$THEME_BUILD_DIR/cms/static/sass"
      mkdir -p "$THEME_BUILD_DIR/cms/templates" "$THEME_BUILD_DIR/cms/static/css" "$THEME_BUILD_DIR/cms/static/sass"
      cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/." "$THEME_BUILD_DIR/cms/templates/" 2>/dev/null || true
      if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css" ]; then
        cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/." "$THEME_BUILD_DIR/cms/static/css/"
      fi
      if [ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass" ]; then
        cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass/." "$THEME_BUILD_DIR/cms/static/sass/"
      fi
    fi
  else
    echo "Warning: Theme build directory not found. Logo sync skipped."
  fi

  # Sync custom apps into build context
  local CUSTOM_APPS_SRC="$REPO_ROOT/infrastructure/tutor/custom-apps"
  local CUSTOM_APPS_DEST="$REPO_ROOT/tutor_env/env/build/openedx/infrastructure/tutor/custom-apps"
  if [ -d "$CUSTOM_APPS_SRC" ] && [ -d "$REPO_ROOT/tutor_env/env/build/openedx" ]; then
    # Keep the rendered custom-app build context as a true mirror of source so
    # deleted apps do not linger under tutor_env/ across repeated patch runs.
    rm -rf "$CUSTOM_APPS_DEST"
    mkdir -p "$CUSTOM_APPS_DEST"
    cp -R "$CUSTOM_APPS_SRC/." "$CUSTOM_APPS_DEST/"
    echo "Custom apps synced to build context."
  else
    echo "Warning: Custom apps sync skipped (missing build context)."
  fi

  # Sync multi-tenancy plugin into build context
  local TENANCY_PLUGIN_SRC="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy"
  local TENANCY_PLUGIN_DEST="$REPO_ROOT/tutor_env/env/build/openedx/infrastructure/tutor/plugins/multi-tenancy"
  if [ -d "$TENANCY_PLUGIN_SRC" ] && [ -d "$REPO_ROOT/tutor_env/env/build/openedx" ]; then
    rm -rf "$TENANCY_PLUGIN_DEST"
    mkdir -p "$TENANCY_PLUGIN_DEST"
    cp -R "$TENANCY_PLUGIN_SRC/." "$TENANCY_PLUGIN_DEST/"
    echo "Multi-tenancy plugin synced to build context."
  else
    echo "Warning: Multi-tenancy plugin sync skipped (missing build context)."
  fi
}
