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

STATIC_PAYLOAD_TRIM_RE = re.compile(
    r"RUN rm -rf /openedx/staticfiles/stylelint-config-edx \\\n"
    r"(?:\s+/openedx/staticfiles/[^\n]+(?: \\\n|\n))+",
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

    # Keep uwsgi on plain pip for now: a local uv preflight against uwsgi==2.0.24
    # still fails in wheel build with C compiler errors around signal handler
    # signatures. Treat this as an explicit compatibility exception, not a
    # forgotten uv seam.

    build_profile_arg = "ARG MEREKA_BUILD_PROFILE=proof\n"
    custom_app_install_mode_arg = "ARG MEREKA_CUSTOM_APP_INSTALL_MODE=editable\n"
    if build_profile_arg not in updated and custom_app_install_mode_arg in updated:
        updated = updated.replace(
            custom_app_install_mode_arg,
            build_profile_arg + custom_app_install_mode_arg,
            1,
        )

    updated = updated.replace(
        "RUN make clean_translations",
        "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping translation refresh (fast build profile)\"; else make clean_translations; fi",
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

    if path.name == "Dockerfile" and "/openedx/edx-platform" in updated:
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
        # Upstream/local render inputs can still emit DEFAULT_SITE_THEME twice.
        # Keep the first canonical mereka assignment and strip later duplicates
        # without preserving the old broad runtime-cluster scrubber.
        theme_marker = '\n# Set default theme for all sites\nDEFAULT_SITE_THEME = "mereka"\n'
        first_theme = updated.find(theme_marker)
        last_theme = updated.rfind(theme_marker)
        if first_theme != -1 and last_theme != -1 and first_theme != last_theme:
            updated = updated[:last_theme] + updated[last_theme + len(theme_marker):]

    # ── assets.py patches ───────────────────────────────────────────────

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
