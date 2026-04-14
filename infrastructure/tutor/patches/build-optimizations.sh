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
import sys

targets = sys.argv[1:]

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

    custom_app_install_mode_arg = "ARG MEREKA_CUSTOM_APP_INSTALL_MODE=editable\n"

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

    # ── assets.py patches ───────────────────────────────────────────────

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
