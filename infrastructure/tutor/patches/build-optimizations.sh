#!/usr/bin/env bash
# Patch: Build optimizations and openedx Dockerfile/settings patches.
# Target: Tutor 21.x (Ulmo). Some replacements target Redwood-era template
# patterns and are harmless no-ops on Ulmo (str.replace returns unchanged text).
# Covers: pip retries, compile-sass, collectstatic fixes, i18n fixes,
#         custom apps, django settings (discussions, theme, oauth fix,
#         tenancy), assets.py (JS_COMPRESSOR, safe_join), MFE cache headers,
#         nginx health/profile endpoints, Caddy profile proxy.

apply_build_optimizations_patch() {
  local rendered_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local targets=(
    "$OPENEDX_TEMPLATE"
    "$rendered_root/env/build/openedx/Dockerfile"
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
    "$rendered_root/env/plugins/mfe/build/mfe/Dockerfile"
    "$LMS_SETTINGS_TEMPLATE"
    "$rendered_root/env/apps/openedx/settings/lms/production.py"
    "$LMS_ASSETS_TEMPLATE"
    "$rendered_root/env/build/openedx/settings/lms/assets.py"
    "$CMS_ASSETS_TEMPLATE"
    "$rendered_root/env/build/openedx/settings/cms/assets.py"
    "$NGINX_LMS_TEMPLATE"
    "$rendered_root/env/apps/nginx/lms.conf"
    "$CADDY_TEMPLATE"
    "$rendered_root/env/apps/caddy/Caddyfile"
  )

  "${PYTHON_BIN}" - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import textwrap
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    # ── openedx Dockerfile patches ──────────────────────────────────────

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
        "pip install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt -r /openedx/edx-platform/requirements/edx/assets.txt",
    )
    updated = updated.replace(
        "$PIP_COMMAND install -r requirements/edx/development.txt",
        "$PIP_COMMAND install --no-build-isolation -r requirements/edx/development.txt",
    )
    updated = updated.replace(
        "RUN pip install setuptools==44.1.0 pip==20.0.2 wheel==0.34.2",
        "RUN pip install --upgrade pip==25.0.1 setuptools==75.3.0 wheel==0.45.1",
    )

    # pip install retry wrapping
    updated = updated.replace(
        "RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\\n    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\\n    pip install -r /openedx/edx-platform/requirements/edx/base.txt",
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "pip install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
    )
    updated = updated.replace(
        "RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\\n    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\\n    bash -o pipefail -c 'for attempt in 1 2 3; do \\n        pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0 \\n        echo \"pip install attempt ${attempt} failed; retrying in 10s\" >&2 \\n        sleep 10 \\n    done; exit 1'",
        """RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/openedx/edx-platform/requirements/edx/base.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "pip install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
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
    bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo "pip install attempt ${attempt} failed; retrying in 10s" >&2; sleep 10; done; exit 1'""",
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

    # compilejsi18n
    updated = updated.replace(
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n\nRUN ./manage.py cms --settings=tutor.i18n compilejsi18n\n",
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n\n"
        "RUN ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n\n",
    )
    updated = updated.replace(
        "# Redwood skips manual compilejsi18n while content libraries mature.\n",
        "RUN ./manage.py lms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/js/i18n\n"
        "RUN ./manage.py cms --settings=tutor.i18n compilejsi18n --output /openedx/staticfiles/studio/js/i18n\n",
    )

    # REMOVED: Redwood-era node_modules COPY path fixes + node cache reuse (FROM overhangio/openedx:18.2.2)
    # This was a Tutor 18/Redwood optimization that copied node_modules from the upstream
    # Redwood image. Incompatible with Ulmo (different node version, package structure).
    # Tutor 21's standard node install with BuildKit cache is the correct approach.

    # brand compile block (sass + google fonts strip)
    brand_compile_block = (
        "RUN python - <<'PY'\n"
        "from pathlib import Path\n"
        "import re\n"
        "\n"
        "# Studio (CMS) still tries to import Open Sans from Google fonts by default.\n"
        "# We strip those imports at the SASS source so built CSS stays offline-friendly.\n"
        "root = Path('/openedx/edx-platform')\n"
        "patterns = [\n"
        "    re.compile(r'@import\\s+url\\([\\\"\\']?https?://fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+url\\([\\\"\\']?//fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+[\\\"\\']https?://fonts[.]googleapis[.]com[^\\\"\\']*[\\\"\\']\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+[\\\"\\']//fonts[.]googleapis[.]com[^\\\"\\']*[\\\"\\']\\s*;?', re.I),\n"
        "]\n"
        "changed = 0\n"
        "for path in root.rglob('*.scss'):\n"
        "    try:\n"
        "        text = path.read_text(encoding='utf-8', errors='ignore')\n"
        "    except Exception:\n"
        "        continue\n"
        "    updated = text\n"
        "    for pat in patterns:\n"
        "        updated = pat.sub('', updated)\n"
        "    if updated != text:\n"
        "        path.write_text(updated, encoding='utf-8')\n"
        "        changed += 1\n"
        "print(f'Stripped google font imports from {changed} scss files')\n"
        "PY\n"
        "RUN npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka && npm run compile-sass -- --skip-themes\n"
        "RUN python - <<'PY'\n"
        "from pathlib import Path\n"
        "import re\n"
        "\n"
        "# Defense-in-depth: remove any residual Google font imports from compiled Studio CSS.\n"
        "root = Path('/openedx/edx-platform')\n"
        "patterns = [\n"
        "    re.compile(r'@import\\s+url\\([\\\"\\']?https?://fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+url\\([\\\"\\']?//fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+[\\\"\\']https?://fonts[.]googleapis[.]com[^\\\"\\']*[\\\"\\']\\s*;?', re.I),\n"
        "    re.compile(r'@import\\s+[\\\"\\']//fonts[.]googleapis[.]com[^\\\"\\']*[\\\"\\']\\s*;?', re.I),\n"
        "]\n"
        "changed = 0\n"
        "for path in root.rglob('studio-main-v1*.css'):\n"
        "    try:\n"
        "        text = path.read_text(encoding='utf-8', errors='ignore')\n"
        "    except Exception:\n"
        "        continue\n"
        "    updated = text\n"
        "    for pat in patterns:\n"
        "        updated = pat.sub('', updated)\n"
        "    if updated != text:\n"
        "        path.write_text(updated, encoding='utf-8')\n"
        "        changed += 1\n"
        "print(f'Stripped google font imports from {changed} compiled studio css files')\n"
        "PY"
    )
    compile_patch_marker = "Stripped google font imports from {changed} scss files"
    if compile_patch_marker not in updated:
        old_conditional_compile = (
            'RUN if [ ! -f /openedx/edx-platform/lms/static/css/lms-main.css ]; then npm run compile-sass -- --skip-themes; else echo "compile-sass skipped (prebuilt assets)"; fi'
        )
        if old_conditional_compile in updated:
            updated = updated.replace(old_conditional_compile, brand_compile_block, 1)
        else:
            current_compile_block = (
                "RUN npm run compile-sass -- --skip-themes\n"
                "RUN npm run webpack\n"
            )
            if current_compile_block in updated:
                updated = updated.replace(current_compile_block, f"{brand_compile_block}\nRUN npm run webpack\n", 1)
    if compile_patch_marker in updated:
        updated = updated.replace("\nRUN npm run compile-sass -- --skip-default\n", "\n")
        updated = updated.replace("fonts\\\\.googleapis\\\\.com", "fonts[.]googleapis[.]com")

    # webpack conditional
    webpack_conditional = (
        'RUN if [ ! -f /openedx/edx-platform/common/static/bundles/commons.js ]; then npm run webpack; else echo "webpack skipped (prebuilt bundles)"; fi'
    )
    updated = updated.replace("RUN npm run webpack", webpack_conditional)

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
        hardened_mfe_base_apt = """RUN printf 'Acquire::Retries "6";\\nAcquire::http::Timeout "30";\\nAcquire::https::Timeout "30";\\nAcquire::ForceIPv4 "true";\\n' > /etc/apt/apt.conf.d/80-retries && \\
    apt-get update \\
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing git \\
    # required for cwebp-bin
    gcc libgl1 libxi6 make \\
    # required for gifsicle, mozjpeg, and optipng (on arm)
    autoconf libtool pkg-config zlib1g-dev \\
    # required for node-sass (on arm)
    python3 g++ python3-distutils \\
    # required for image-webpack-loader (on arm)
    libpng-dev \\
    # required for building node-canvas (on arm, for authoring)
    # https://www.npmjs.com/package/canvas
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \\
 && rm -rf /var/lib/apt/lists/*"""
        updated = re.sub(
            r"""RUN printf 'Acquire::Retries "5";\\nAcquire::http::Timeout "120";\\n' > /etc/apt/apt\.conf\.d/80-retries && \\\n\s+apt-get update \\\n\s+&& apt-get install -y --fix-broken git \\\n\s+# required for cwebp-bin\n\s+gcc libgl1 libxi6 make \\\n\s+# required for gifsicle, mozjpeg, and optipng \(on arm\)\n\s+autoconf libtool pkg-config zlib1g-dev \\\n\s+# required for node-sass \(on arm\)\n\s+python3 g\+\+ python3-distutils \\\n\s+# required for image-webpack-loader \(on arm\)\n\s+libpng-dev \\\n\s+# required for building node-canvas \(on arm, for authoring\)\n\s+# https://www\.npmjs\.com/package/canvas\n\s+libcairo2-dev libpango1\.0-dev libjpeg-dev libgif-dev librsvg2-dev""",
            hardened_mfe_base_apt,
            updated,
            count=1,
        )

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

        updated = updated.replace(
            "RUN npm install '@edx/brand@github:@edly-io/brand-openedx#indigo-2.5.0'",
            "RUN npm install --legacy-peer-deps '@edx/brand@npm:@edly-io/indigo-brand-openedx@^2.4.2'",
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

    # Custom apps block in Dockerfile
    if path.name == "Dockerfile" and "/openedx/edx-platform" in updated:
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
RUN pip install django-prometheus==2.3.1"""
                updated = updated.replace(base_req_marker, prometheus_install)

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

        if "_safe_add_app('mfe_oauth_fix')" in updated and "INSTALLED_APPS.append('mfe_oauth_fix')" in updated:
            updated = re.sub(
                r"\n# Set default theme for all sites\n"
                r'DEFAULT_SITE_THEME = "mereka"\n\n'
                r"# MFE OAuth Fix - Custom app to fix OAuth provider visibility\n"
                r"import sys\n"
                r"sys\.path\.insert\(0, '/openedx'\)\n"
                r"INSTALLED_APPS\.append\('mfe_oauth_fix'\)\n\n"
                r"# Add middleware to fix /api/mfe_context responses\n"
                r"# Insert at the end of middleware stack so it processes responses\n"
                r"MIDDLEWARE\.append\('mfe_oauth_fix\.middleware\.MFEOAuthFixMiddleware'\)\n\n"
                r"# Prometheus Metrics Integration\n"
                r"# django_prometheus must be added at the START of INSTALLED_APPS\n"
                r"if 'django_prometheus' not in INSTALLED_APPS:\n"
                r"    INSTALLED_APPS\.insert\(0, 'django_prometheus'\)\n\n"
                r"# Add custom prometheus app for /metrics endpoint\n"
                r"if 'openedx_prometheus' not in INSTALLED_APPS:\n"
                r"    INSTALLED_APPS\.append\('openedx_prometheus'\)\n\n"
                r"# Prometheus middleware must wrap all other middleware\n"
                r"if 'django_prometheus\.middleware\.PrometheusBeforeMiddleware' not in MIDDLEWARE:\n"
                r"    MIDDLEWARE\.insert\(0, 'django_prometheus\.middleware\.PrometheusBeforeMiddleware'\)\n"
                r"if 'django_prometheus\.middleware\.PrometheusAfterMiddleware' not in MIDDLEWARE:\n"
                r"    MIDDLEWARE\.append\('django_prometheus\.middleware\.PrometheusAfterMiddleware'\)\n",
                "\n",
                updated,
                count=1,
            )

        if "_safe_add_app('mereka_tenancy')" in updated and "INSTALLED_APPS.append('mereka_tenancy')" in updated:
            updated = re.sub(
                r"\n# Mereka Multi-Tenancy — tenant model extensions \+ resolution middleware\n"
                r"# See: specs/multi-tenancy-architecture_spec\.md\n"
                r"import sys as _mt_sys\n"
                r"if '/openedx' not in _mt_sys\.path:\n"
                r"    _mt_sys\.path\.insert\(0, '/openedx'\)\n"
                r"if 'mereka_tenancy' not in INSTALLED_APPS:\n"
                r"    INSTALLED_APPS\.append\('mereka_tenancy'\)\n\n"
                r"# TenantResolutionMiddleware resolves hostname → Site → EnterpriseCustomer\n"
                r"# Insert after CurrentSiteMiddleware so Site is already resolved\.\n"
                r"if 'mereka_tenancy\.middleware\.TenantResolutionMiddleware' not in MIDDLEWARE:\n"
                r"    _site_mw = 'django\.contrib\.sites\.middleware\.CurrentSiteMiddleware'\n"
                r"    if _site_mw in MIDDLEWARE:\n"
                r"        _idx = MIDDLEWARE\.index\(_site_mw\) \+ 1\n"
                r"        MIDDLEWARE\.insert\(_idx, 'mereka_tenancy\.middleware\.TenantResolutionMiddleware'\)\n"
                r"    else:\n"
                r"        MIDDLEWARE\.append\('mereka_tenancy\.middleware\.TenantResolutionMiddleware'\)\n",
                "\n",
                updated,
                count=1,
            )
            updated = updated.replace(
                "if 'mereka_tenancy' not in INSTALLED_APPS:\n    INSTALLED_APPS.append('mereka_tenancy')\n",
                "",
                1,
            )

        # DEFAULT_SITE_THEME
        if "DEFAULT_SITE_THEME" not in updated:
            updated = updated.rstrip() + '\n\n# Set default theme for all sites\nDEFAULT_SITE_THEME = "mereka"\n'

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
    mkdir -p "$THEME_BUILD_DIR/lms/static/images"
    for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                     logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                     favicon.ico; do
      src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images/$logo_file"
      if [ -f "$src_file" ]; then
        cp "$src_file" "$THEME_BUILD_DIR/lms/static/images/$logo_file"
        echo "  Copied $logo_file to LMS theme"
      fi
    done

    if [ -d "$THEME_BUILD_DIR/cms" ]; then
      mkdir -p "$THEME_BUILD_DIR/cms/static/images"
      for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                       logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                       favicon.ico; do
        src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images/$logo_file"
        if [ -f "$src_file" ]; then
          cp "$src_file" "$THEME_BUILD_DIR/cms/static/images/$logo_file"
          echo "  Copied $logo_file to CMS theme"
        fi
      done
    fi
    echo "Logo files synced successfully."

    # Copy font assets
    echo "Syncing font files from theme source to build directory..."
    mkdir -p "$THEME_BUILD_DIR/lms/static/fonts"
    if compgen -G "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts/*.woff2" >/dev/null; then
      cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts/"*.woff2 "$THEME_BUILD_DIR/lms/static/fonts/"
      echo "  Copied fonts to LMS theme"
    else
      echo "  No LMS fonts found to copy"
    fi

    if [ -d "$THEME_BUILD_DIR/cms" ]; then
      mkdir -p "$THEME_BUILD_DIR/cms/static/fonts"
      if compgen -G "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts/*.woff2" >/dev/null; then
        cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts/"*.woff2 "$THEME_BUILD_DIR/cms/static/fonts/"
        echo "  Copied fonts to CMS theme"
      else
        echo "  No CMS fonts found to copy"
      fi
    fi

    # Sync theme templates/static overrides
    echo "Syncing theme templates/static overrides to build directory..."
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
    mkdir -p "$TENANCY_PLUGIN_DEST"
    rm -rf "$TENANCY_PLUGIN_DEST"
    mkdir -p "$TENANCY_PLUGIN_DEST"
    cp -R "$TENANCY_PLUGIN_SRC/." "$TENANCY_PLUGIN_DEST/"
    echo "Multi-tenancy plugin synced to build context."
  else
    echo "Warning: Multi-tenancy plugin sync skipped (missing build context)."
  fi
}
