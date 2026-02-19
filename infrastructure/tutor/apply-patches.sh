#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/.venv/bin/activate"

BRANDING_CHECK="$REPO_ROOT/scripts/branding/verify-branding-health.sh"
if [[ -x "$BRANDING_CHECK" ]]; then
  "$BRANDING_CHECK"
fi

MFE_TEMPLATE=$(python - <<'PY'
import inspect
import tutormfe
from pathlib import Path
print(Path(inspect.getfile(tutormfe)).parent / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
PY
)

MFE_INDIGO_ENV_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutorindigo
print(Path(tutorindigo.__file__).parent / "templates" / "indigo" / "env.config.jsx")
PY
)

MYSQL_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "local" / "docker-compose.yml")
PY
)

OPENEDX_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "Dockerfile")
PY
)

# FORUM_ENTRYPOINT_TEMPLATE removed in v21 - Python forum integrated into LMS, no separate container

CADDY_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "caddy" / "Caddyfile")
PY
)

NGINX_LMS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "nginx" / "lms.conf")
PY
)

LMS_SETTINGS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "openedx" / "settings" / "lms" / "production.py")
PY
)

LMS_ASSETS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "lms" / "assets.py")
PY
)

# FORUM_PLUGIN still exists in v21 but structure simplified (no DD_TRACE_ENABLED patch needed)

CMS_ASSETS_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "settings" / "cms" / "assets.py")
PY
)

WEBPACK_PROD_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "build" / "openedx" / "edx-platform" / "webpack.prod.config.js")
PY
)

PATCH_TARGETS=(
  "$MFE_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
  "$MFE_INDIGO_ENV_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
  "$MYSQL_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/local/docker-compose.yml"
  "$OPENEDX_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile"
  # Forum patches removed in v21 - Python forum integrated into LMS
  "$CADDY_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile"
  "$NGINX_LMS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf"
  "$LMS_SETTINGS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
  "$LMS_ASSETS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/settings/lms/assets.py"
  "$CMS_ASSETS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/settings/cms/assets.py"
  "$WEBPACK_PROD_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/edx-platform/webpack.prod.config.js"
)

python - "${PATCH_TARGETS[@]}" <<'PY'
from pathlib import Path
import re
import sys
import textwrap

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original
    # DD_TRACE_ENABLED patch removed - Ruby forum (Mongoid) no longer exists in v21
    extra_lms_hosts = [
        "academy.biji-biji.com",
        "skillourfuture.academy.mereka.io",
    ]
    extra_csrf_origins = [
        "https://academy.biji-biji.com",
        "https://apps.academy.biji-biji.com",
        "https://skillourfuture.academy.mereka.io",
    ]

    def ensure_allowed_hosts(text):
        marker = "ALLOWED_HOSTS = ["
        if marker not in text:
            return text
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if line.strip().startswith(marker):
                end_idx = idx
                while end_idx < len(lines):
                    if lines[end_idx].strip().endswith("]"):
                        break
                    end_idx += 1
                indent = line[: len(line) - len(line.lstrip())] + "    "
                existing = set()
                for entry_line in lines[idx + 1 : end_idx]:
                    stripped = entry_line.strip().rstrip(",")
                    if stripped.startswith(("'", '"')):
                        existing.add(stripped.strip('"\''))
                inserts = []
                for host in extra_lms_hosts:
                    if host not in existing:
                        inserts.append(f'{indent}"{host}",')
                if inserts:
                    lines = lines[:end_idx] + inserts + lines[end_idx:]
                return "\n".join(lines)
        return text

    def ensure_csrf_origins(text):
        anchor = 'CSRF_TRUSTED_ORIGINS.append("apps.academyv2.mereka.io")'
        if anchor not in text:
            return text
        inserts = ""
        for origin in extra_csrf_origins:
            if origin not in text:
                inserts += f'\nCSRF_TRUSTED_ORIGINS.append("{origin}")'
        if not inserts:
            return text
        index = text.index(anchor) + len(anchor)
        return text[:index] + inserts + text[index:]

    def force_mfe_discussions_only(text):
        """Force all courses to use MFE discussions, disable legacy Django views."""
        if "lms/production.py" not in str(path):
            return text

        # Check if already patched
        if "# Force MFE-only discussions (greenfield" in text:
            return text

        # Find the last occurrence of ENABLE_DISCUSSION_SERVICE and insert after it
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

        # Find last occurrence of the marker and insert after that line
        lines = text.splitlines()
        last_idx = None
        for idx, line in enumerate(lines):
            if marker in line and not line.strip().startswith("#"):
                last_idx = idx

        if last_idx is not None:
            lines.insert(last_idx + 1, mfe_config)
            return "\n".join(lines)

        return text

    def ensure_mfe_cookie_env(text):
        marker = "ENV MFE_CONFIG_API_URL=/api/mfe_config/v1"
        if marker not in text or "SESSION_COOKIE_DOMAIN" in text:
            return text
        cookie_block = (
            "ENV MFE_CONFIG_API_URL=/api/mfe_config/v1\n"
            "ARG SESSION_COOKIE_DOMAIN=.localhost\n"
            "ARG CSRF_COOKIE_DOMAIN=.localhost\n"
            "ENV SESSION_COOKIE_DOMAIN=${SESSION_COOKIE_DOMAIN}\n"
            "ENV CSRF_COOKIE_DOMAIN=${CSRF_COOKIE_DOMAIN}"
        )
        return text.replace(marker, cookie_block)

    def ensure_mfe_theme_copy(text):
        env_copy = "COPY indigo/env.config.jsx /openedx/app/"
        theme_copy = "COPY indigo/mereka /openedx/app/mereka"

        # Keep existing env.config copy blocks idempotent by enforcing a single
        # adjacent theme copy line.
        lines = text.splitlines()
        normalized = []
        index = 0
        while index < len(lines):
            line = lines[index]
            normalized.append(line)
            if line.strip() == env_copy:
                next_index = index + 1
                while next_index < len(lines) and lines[next_index].strip() == theme_copy:
                    next_index += 1
                normalized.append(theme_copy)
                index = next_index
                continue
            index += 1

        # Tutor template drift can omit theme copy wiring in authn-common.
        # Enforce parity with other MFEs by inserting both copy lines there.
        lines = normalized

        # Prefer a single global theme copy in the base stage so the shared env.config.jsx
        # can safely import `./mereka/mereka.scss` across *all* MFEs.
        base_anchor = "WORKDIR /openedx/app"
        has_global_copy = any(line.strip() == theme_copy for line in lines[:50])
        if base_anchor in text and not has_global_copy:
            patched = []
            inserted = False
            for line in lines:
                patched.append(line)
                if not inserted and line.strip() == base_anchor:
                    patched.append(theme_copy)
                    inserted = True
            lines = patched

        start = None
        for idx, line in enumerate(lines):
            if line.strip() == "FROM base AS authn-common":
                start = idx
                break
        if start is not None:
            end = len(lines)
            for idx in range(start + 1, len(lines)):
                stripped = lines[idx].strip()
                if stripped.startswith("######## ") or stripped.startswith("####################### "):
                    end = idx
                    break
            authn_block = lines[start:end]
            has_env_copy = any(line.strip() == env_copy for line in authn_block)
            has_theme_copy = any(line.strip() == theme_copy for line in authn_block)

            if not (has_env_copy and has_theme_copy):
                insert_at = None
                for idx in range(start, end):
                    if lines[idx].strip() == "COPY --from=authn-src / /openedx/app":
                        insert_at = idx
                        break
                if insert_at is None:
                    for idx in range(start, end):
                        if lines[idx].strip().startswith("RUN make OPENEDX_ATLAS_PULL="):
                            insert_at = idx
                            break
                if insert_at is not None:
                    inserts = []
                    if not has_env_copy:
                        inserts.append(env_copy)
                    if not has_theme_copy:
                        inserts.append(theme_copy)
                    lines = lines[:insert_at] + inserts + lines[insert_at:]

        rebuilt = "\n".join(lines)
        if text.endswith("\n"):
            rebuilt += "\n"
        return rebuilt

    def ensure_mfe_npm_resilience(text):
        if "npm clean-install" not in text:
            return text
        # If we've already injected the fallback markers, still normalize any prior escaping
        # that would break shell parsing (e.g., `echo \"...; ...\"`).
        if "npm clean-install attempt ${attempt} failed; attempting npm install fallback" in text:
            if 'echo \\"' in text or '\\" >&2;' in text:
                text = text.replace('echo \\"', 'echo "')
                text = text.replace('\\" >&2;', '" >&2;')
            return text

        # Upgrade older resilience patch blocks (retries only) to include an `npm install` fallback.
        retry_only = re.compile(
            r"bash -o pipefail -c 'for attempt in 1 2 3; do "
            r"(npm clean-install [^;]+--registry=\$NPM_REGISTRY) && exit 0; "
            r"echo \"npm clean-install attempt \${attempt} failed; retrying in 15s\" >&2; "
            r"sleep 15; done; exit 1'"
        )
        text = retry_only.sub(
            "bash -o pipefail -c 'for attempt in 1 2 3; do "
            "\\1 && exit 0; "
            'echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; '
            "npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; "
            'echo "npm clean-install attempt ${attempt} failed; retrying in 15s" >&2; '
            "sleep 15; done; exit 1'",
            text,
        )
        run_line = (
            "RUN --mount=type=cache,target=/root/.npm,sharing=shared "
            "npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY"
        )
        resilient_block = (
            "RUN --mount=type=cache,target=/root/.npm,sharing=shared \\\n"
            "    npm config set fetch-retries 6 \\\n"
            " && npm config set fetch-retry-mintimeout 20000 \\\n"
            " && npm config set fetch-retry-maxtimeout 120000 \\\n"
            " && npm config set fetch-timeout 300000 \\\n"
            " && bash -o pipefail -c 'for attempt in 1 2 3; do "
            "npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; "
            # Upstream MFE repos occasionally ship with package-lock drift that breaks `npm ci`/`npm clean-install`.
            # Fall back to `npm install` to unblock builds while still preferring the lockfile path when it works.
            'echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; '
            "npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; "
            'echo "npm clean-install attempt ${attempt} failed; retrying in 15s" >&2; '
            "sleep 15; "
            "done; exit 1'"
        )
        updated_text = text.replace(run_line, resilient_block)
        if updated_text != text:
            return updated_text
        pattern = re.compile(
            r"RUN\s+--mount=type=cache,target=/root/\.npm,sharing=shared\s+npm clean-install --no-audit --registry=\$NPM_REGISTRY"
        )
        return pattern.sub(
            "RUN --mount=type=cache,target=/root/.npm,sharing=shared \\\n"
            "    npm config set fetch-retries 6 \\\n"
            " && npm config set fetch-retry-mintimeout 20000 \\\n"
            " && npm config set fetch-retry-maxtimeout 120000 \\\n"
            " && npm config set fetch-timeout 300000 \\\n"
            " && bash -o pipefail -c 'for attempt in 1 2 3; do "
            "npm clean-install --no-audit --registry=$NPM_REGISTRY && exit 0; "
            'echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; '
            "npm install --no-audit --registry=$NPM_REGISTRY && exit 0; "
            'echo "npm clean-install attempt ${attempt} failed; retrying in 15s" >&2; '
            "sleep 15; "
            "done; exit 1'",
            text,
        )

    def ensure_mfe_plugin_framework_dependency(text):
        plugin_line = "RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'"
        legacy_line = "RUN npm install '@openedx/frontend-plugin-framework@^1.8.0'"
        if legacy_line in text:
            text = text.replace(legacy_line, plugin_line)
        if plugin_line in text:
            return text
        brand_line = "RUN npm install '@edx/brand@npm:@edly-io/indigo-brand-openedx@^2.1.1'"
        if brand_line not in text:
            return text
        return text.replace(brand_line, f"{brand_line}\n{plugin_line}")

    def ensure_mfe_admin_console_redux_deps(text):
        """
        `frontend-app-admin-console` can import frontend-platform's OptionalReduxProvider which expects
        `react-redux` to be present at build time. In some upstream combinations it is not installed
        (peer dependency drift), which breaks `npm run build`.
        """
        if "FROM base AS admin-console-common" not in text:
            return text
        if "react-redux" in text:
            return text

        plugin_line = "RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'"
        redux_line = "RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1'"

        lines = text.splitlines()
        start = None
        for idx, line in enumerate(lines):
            if line.strip() == "FROM base AS admin-console-common":
                start = idx
                break
        if start is None:
            return text

        end = len(lines)
        for idx in range(start + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("######## ") or stripped.startswith("####################### "):
                end = idx
                break

        for idx in range(start, end):
            if lines[idx].strip() == plugin_line:
                # Insert right after the plugin-framework install, within the admin-console-common stage.
                lines.insert(idx + 1, redux_line)
                rebuilt = "\n".join(lines)
                if text.endswith("\n"):
                    rebuilt += "\n"
                return rebuilt

        return text

    # Ensure MFEs build against Node 18 with the required toolchain.
    #
    # Tutor/upstream templates can drift between Node major versions (12 -> 18 -> 24 ...).
    # We standardize *any* node base image reference in the MFE build Dockerfile to Node 18,
    # which is the supported baseline for our current MFE patch stack.
    updated = re.sub(
        r"^FROM\s+(?:docker[.]io/)?node:[^ \t\r\n]+",
        "FROM docker.io/node:18-bullseye-slim",
        updated,
        flags=re.MULTILINE,
    )
    if "gcc git libgl1 libxi6 make" in updated:
        updated = updated.replace(
            "gcc git libgl1 libxi6 make",
            "gcc g++ git libgl1 libxi6 make python3 python3-distutils",
        )

    def ensure_mfe_course_authoring_directory_fix(text):
        """
        Fix course-authoring MFE directory name mismatch (mereka-lms-3f8g).
        Tutor MFE plugin expects 'course-authoring' but build produces 'frontend-app-course-authoring'.
        Add a symlink or rename step in the Dockerfile to align names.
        """
        if "FROM base AS course-authoring-common" not in text:
            return text
        if "ln -s /openedx/app/frontend-app-course-authoring /openedx/app/course-authoring" in text:
            return text

        lines = text.splitlines()
        start = None
        for idx, line in enumerate(lines):
            if line.strip() == "FROM base AS course-authoring-common":
                start = idx
                break
        if start is None:
            return text

        # Find the end of this stage (next FROM or end of file)
        end = len(lines)
        for idx in range(start + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("######## ") or stripped.startswith("FROM "):
                end = idx
                break

        # Insert symlink creation after WORKDIR line
        for idx in range(start, end):
            if "WORKDIR /openedx/app" in lines[idx]:
                symlink_cmd = "RUN ln -sf /openedx/app/frontend-app-course-authoring /openedx/app/course-authoring || true"
                lines.insert(idx + 1, symlink_cmd)
                break

        rebuilt = "\n".join(lines)
        if text.endswith("\n"):
            rebuilt += "\n"
        return rebuilt

    def ensure_mfe_cache_headers(text):
        """
        Configure proper cache headers for MFE assets (mereka-lms-2pne).
        HTML files: no-cache to prevent stale blank pages.
        JS/CSS with content-hash: long cache + immutable.
        Applied via Caddy reverse proxy configuration.
        """
        # This patch targets Caddyfile, not Dockerfile
        if "apps.academyv2.mereka.io" not in text or "Caddyfile" not in str(path):
            return text

        # Check if cache headers already configured
        if "Cache-Control" in text and "no-cache" in text:
            return text

        # Find the apps.academyv2.mereka.io block
        needle = "apps.academyv2.mereka.io {"
        if needle not in text:
            return text

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
        # Insert after the opening brace
        text = text.replace(
            needle,
            needle + "\n" + cache_config
        )
        return text

    def ensure_mfe_new_relic_env(text):
        # Ensure New Relic build control flag is carried into production stages.
        # On MFE Dockerfiles, `ARG` scope does not reliably propagate into derived
        # `FROM ... AS ...` stages, but an `ENV` value does.
        if "ARG ENABLE_NEW_RELIC=" not in text:
            return text

        lines = text.splitlines()
        updated_lines = []
        for idx, line in enumerate(lines):
            updated_lines.append(line)
            if not line.startswith("ARG ENABLE_NEW_RELIC="):
                continue
            next_line = lines[idx + 1] if idx + 1 < len(lines) else ""
            if "ENV ENABLE_NEW_RELIC=" in next_line:
                continue
            updated_lines.append("ENV ENABLE_NEW_RELIC=${ENABLE_NEW_RELIC}")
        return "\n".join(updated_lines) + ("\n" if text.endswith("\n") else "\n")

    def ensure_argocd_configmap_ignore(text):
        """
        Add ignoreDifferences for CSS ConfigMaps to prevent ArgoCD churn (mereka-lms-dcd).
        This should be applied to ArgoCD Application manifests, not Tutor templates.
        Since no ArgoCD manifests exist in tutor_env/, document the fix in a separate patch file.
        """
        # This patch is not applied via apply-patches.sh
        # It requires a separate ArgoCD Application patch in deploy/k8s/patches/
        return text

    updated = ensure_mfe_cookie_env(updated)
    updated = ensure_mfe_theme_copy(updated)
    updated = ensure_mfe_npm_resilience(updated)
    updated = ensure_mfe_plugin_framework_dependency(updated)
    updated = ensure_mfe_admin_console_redux_deps(updated)
    updated = ensure_mfe_course_authoring_directory_fix(updated)
    updated = ensure_mfe_cache_headers(updated)
    updated = ensure_mfe_new_relic_env(updated)

    # Allow remote root access when using upstream MySQL images.
    if "MYSQL_ROOT_PASSWORD" in updated and "MYSQL_ROOT_HOST" not in updated:
        lines = updated.splitlines()
        new_lines = []
        for line in lines:
            new_lines.append(line)
            if "MYSQL_ROOT_PASSWORD" in line:
                indent = line[: len(line) - len(line.lstrip())]
                if "{{" in updated:
                    new_lines.append(
                        indent + 'MYSQL_ROOT_HOST: "{{ MYSQL_ROOT_HOST|default(\'%\') }}"'
                    )
                else:
                    new_lines.append(indent + 'MYSQL_ROOT_HOST: "%"')
        # Avoid duplicating the inserted line on successive runs.
        seen = False
        filtered = []
        for line in new_lines:
            if "MYSQL_ROOT_HOST" in line:
                if seen:
                    continue
                seen = True
            filtered.append(line)
        updated = "\n".join(filtered)
    # Normalize braces if a prior run introduced single-brace syntax.
    updated = updated.replace(
        "{ MYSQL_ROOT_HOST|default('%') }", "{{ MYSQL_ROOT_HOST|default('%') }}"
    )
    updated = updated.replace(
        "{{{ MYSQL_ROOT_HOST|default('%') }}}", "{{ MYSQL_ROOT_HOST|default('%') }}"
    )

    # open-release/redwood i18n archive moved under openedx-unsupported.
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

    # Tutor v21+ can use `uv pip` for requirements installs. Some upstream sdists
    # incorrectly import pkg_resources at build time without declaring it in their
    # build-system.requires (e.g. loremipsum). `--no-build-isolation` keeps
    # setuptools/pkg_resources available and prevents hard build failures.
    # CRITICAL: uv pip does NOT support editable Git URLs (e.g. git+https://...#egg=foo).
    # Use plain pip for base.txt/assets.txt which contain editable proctortrack dependency.
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
    updated = updated.replace(
        "# Re-install local requirements, otherwise egg-info folders are missing\nRUN pip install -r requirements/edx/local.in\n\n",
        "# Local requirements list removed in Redwood; skip redundant reinstall step.\n",
    )
    updated = updated.replace(
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\n',
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\n# Mereka adjustments keep Redwood optional apps enabled\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\nif "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]\nif "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]\nif "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]\nif "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.theming.apps.ThemingConfig\"]\n',
    )
    updated = updated.replace(
        "--mysql-native-password=ON",
        "--default-authentication-plugin=mysql_native_password",
    )
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
    updated = updated.replace(
        "RUN cd /openedx/locale/user && \\\n    django-admin.py compilemessages -v1",
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/python -m django compilemessages -v1",
    )
    updated = updated.replace(
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/django-admin.py compilemessages -v1",
        "RUN cd /openedx/locale/user && \\\n    /openedx/venv/bin/python -m django compilemessages -v1",
    )
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
    updated = updated.replace(
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/edx-platform/node_modules /openedx/node_modules",
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/node_modules /openedx/node_modules",
    )
    updated = updated.replace(
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/node_modules /openedx/node_modules\n\n# Symlink node_modules such that we can bind-mount the edx-platform repository",
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/node_modules /openedx/node_modules\nCOPY --chown=app:app ./common/static/bundles /openedx/edx-platform/common/static/bundles\n\n# Symlink node_modules such that we can bind-mount the edx-platform repository",
    )
    updated = updated.replace(
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/node_modules /openedx/node_modules\nCOPY --chown=app:app ./common/static/bundles /openedx/edx-platform/common/static/bundles\n\n# Symlink node_modules such that we can bind-mount the edx-platform repository",
        "COPY --link --chown=$APP_USER_ID:$APP_USER_ID --from=nodejs-requirements /openedx/node_modules /openedx/node_modules\n\n# Symlink node_modules such that we can bind-mount the edx-platform repository",
    )
    old_node_block = """###### Install nodejs with nodeenv in /openedx/nodeenv
FROM python AS nodejs-requirements
ENV PATH=/openedx/nodeenv/bin:/openedx/venv/bin:${PATH}

# Install nodeenv with the version provided by edx-platform
# https://github.com/openedx/edx-platform/blob/master/requirements/edx/base.txt
RUN pip install nodeenv==1.8.0
RUN nodeenv /openedx/nodeenv --node=18.20.1 --prebuilt

# Install nodejs requirements
ARG NPM_REGISTRY=https://registry.npmjs.org/
WORKDIR /openedx/edx-platform
RUN --mount=type=bind,from=edx-platform,source=/package.json,target=/openedx/edx-platform/package.json \\
    --mount=type=bind,from=edx-platform,source=/package-lock.json,target=/openedx/edx-platform/package-lock.json \\
    --mount=type=bind,from=edx-platform,source=/scripts/copy-node-modules.sh,target=/openedx/edx-platform/scripts/copy-node-modules.sh \\
    --mount=type=cache,target=/root/.npm,sharing=shared \\
    npm clean-install --no-audit --registry=$NPM_REGISTRY
"""
    new_node_block = """###### Reuse upstream Redwood node artifacts to avoid local npm installs
FROM docker.io/overhangio/openedx:18.2.2 AS openedx_node_cache

###### Install nodejs with nodeenv in /openedx/nodeenv
FROM python AS nodejs-requirements
ENV PATH=/openedx/nodeenv/bin:/openedx/venv/bin:${PATH}

# Copy prebuilt nodeenv/node_modules instead of re-running npm clean-install
COPY --from=openedx_node_cache /openedx/nodeenv /openedx/nodeenv
COPY --from=openedx_node_cache /openedx/node_modules /openedx/node_modules
WORKDIR /openedx/edx-platform
RUN ln -s /openedx/node_modules /openedx/edx-platform/node_modules
"""
    updated = updated.replace(old_node_block, new_node_block)
    old_node_block_template = """###### Install nodejs with nodeenv in /openedx/nodeenv
FROM python AS nodejs-requirements
ENV PATH=/openedx/nodeenv/bin:/openedx/venv/bin:${PATH}

# Install nodeenv with the version provided by edx-platform
# https://github.com/openedx/edx-platform/blob/master/requirements/edx/base.txt
RUN pip install nodeenv==1.8.0
RUN nodeenv /openedx/nodeenv --node=18.20.1 --prebuilt

# Install nodejs requirements
ARG NPM_REGISTRY={{ NPM_REGISTRY }}
WORKDIR /openedx/edx-platform
RUN --mount=type=bind,from=edx-platform,source=/package.json,target=/openedx/edx-platform/package.json \\
    --mount=type=bind,from=edx-platform,source=/package-lock.json,target=/openedx/edx-platform/package-lock.json \\
    --mount=type=bind,from=edx-platform,source=/scripts/copy-node-modules.sh,target=/openedx/edx-platform/scripts/copy-node-modules.sh \\
    --mount=type=cache,target=/root/.npm,sharing=shared \\
    npm clean-install --no-audit --registry=$NPM_REGISTRY
"""
    updated = updated.replace(old_node_block_template, new_node_block)

    updated = updated.replace(
        'RUN if [ ! -d /openedx/node_modules ] || [ -z "$(ls -A /openedx/node_modules)" ]; then npm run postinstall; else echo "npm run postinstall skipped (prebuilt node_modules)"; fi',
        "RUN npm run postinstall  # Postinstall artifacts are stuck in nodejs-requirements layer. Create them here too.",
    )
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
        # Normalize any legacy over-escaped regex literals left from previous patch versions.
        updated = updated.replace("fonts\\\\.googleapis\\\\.com", "fonts[.]googleapis[.]com")
    webpack_conditional = (
        'RUN if [ ! -f /openedx/edx-platform/common/static/bundles/commons.js ]; then npm run webpack; else echo "webpack skipped (prebuilt bundles)"; fi'
    )
    updated = updated.replace("RUN npm run webpack", webpack_conditional)
    updated = updated.replace(
        "new TerserPlugin(),",
        "new TerserPlugin({ parallel: false }),",
    )
    updated = updated.replace(
        "module.exports = [..._.values(optimizedConfig), ..._.values(requireCompatConfig)];",
        "module.exports = [..._.values(optimizedConfig)];",
    )
    # Fix collectstatic uglify-js parse error by disabling RequireJS r.js minification
    # https://discuss.openedx.org/t/redwood-js-parse-error-occurs-with-manage-py-lms-collectstatic/14133
    updated = updated.replace(
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH="/openedx/edx-platform"\n',
        'ENV NODE_OPTIONS="--max-old-space-size=6144"\nENV PYTHONPATH="/openedx/edx-platform"\nENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none\n',
    )
    updated = updated.replace(
        "derive_settings(__name__)\n\nLOCALE_PATHS.append(\"/openedx/locale/contrib/locale\")\n",
        "derive_settings(__name__)\n\n# Ensure optional Redwood apps exist when collecting assets\nif \"openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig\"]\nif \"openedx.core.djangoapps.bookmarks.apps.BookmarksConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.bookmarks.apps.BookmarksConfig\"]\nif \"openedx.core.djangoapps.discussions.apps.DiscussionsConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.discussions.apps.DiscussionsConfig\"]\nif \"openedx.core.djangoapps.theming.apps.ThemingConfig\" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.theming.apps.ThemingConfig\"]\n\nLOCALE_PATHS.append(\"/openedx/locale/contrib/locale\")\n",
    )
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

    # Fix Tutor v21 node_modules path: npm installs at WORKDIR /openedx/edx-platform
    # but COPY expects /openedx/node_modules. Move node_modules after install.
    if path.name == "Dockerfile" and "nodejs-requirements" in updated:
        npm_install_marker = "npm clean-install --no-audit --registry=$NPM_REGISTRY"
        node_mv = "npm clean-install --no-audit --registry=$NPM_REGISTRY\nRUN mv /openedx/edx-platform/node_modules /openedx/node_modules"
        if npm_install_marker in updated and "mv /openedx/edx-platform/node_modules" not in updated:
            updated = updated.replace(npm_install_marker, node_mv)

    # Add custom apps to Dockerfile
    if path.name == "Dockerfile" and "/openedx/edx-platform" in updated:
        # Find the line where we copy themes and add our custom apps after it
        copy_themes_marker = "COPY --chown=app:app themes/ /openedx/themes/"
        copy_themes_marker_alt = "COPY --chown=app:app ./themes/ /openedx/themes"
        custom_apps_block = """# Copy custom apps
COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus
RUN pip install -e /openedx/plugins/mereka_tenancy

# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there as top-level Django apps.
RUN printf '/openedx\\n/openedx/plugins\\n' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth"""
        if (copy_themes_marker in updated or copy_themes_marker_alt in updated) and "RUN pip install -e /openedx/mfe_oauth_fix" not in updated:
            marker = copy_themes_marker if copy_themes_marker in updated else copy_themes_marker_alt
            custom_apps_copy = f"""{marker}
{custom_apps_block}"""
            updated = updated.replace(marker, custom_apps_copy)
        elif "mfe_oauth_fix" in updated and "openedx_prometheus" not in updated:
            # Add prometheus app alongside existing mfe_oauth_fix
            mfe_oauth_marker = "COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix"
            custom_apps_add = f"""{mfe_oauth_marker}
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus
RUN pip install -e /openedx/plugins/mereka_tenancy

# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there as top-level Django apps.
RUN printf '/openedx\\n/openedx/plugins\\n' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth"""
            updated = updated.replace(mfe_oauth_marker, custom_apps_add)
        elif "mfe_oauth_fix" not in updated and "openedx_prometheus" not in updated:
            # If themes copy doesn't exist, add before WORKDIR /openedx/edx-platform
            workdir_marker = "WORKDIR /openedx/edx-platform\n"
            if workdir_marker in updated:
                custom_app_insert = f"""# Copy custom apps
COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus
RUN pip install -e /openedx/plugins/mereka_tenancy

# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there as top-level Django apps.
RUN printf '/openedx\\n/openedx/plugins\\n' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth

""" + workdir_marker
                updated = updated.replace(workdir_marker, custom_app_insert, 1)

        # Install django-prometheus after pip install of base requirements
        # Also install pymongo SRV extras for MongoDB Atlas (dnspython)
        base_req_marker = "bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo \"pip install attempt ${attempt} failed; retrying in 10s\" >&2; sleep 10; done; exit 1'"
        if base_req_marker in updated:
            if "django-prometheus" not in updated:
                # Add django-prometheus install after base requirements
                prometheus_install = base_req_marker + """\n\n# Install django-prometheus for metrics
RUN pip install django-prometheus==2.3.1"""
                updated = updated.replace(base_req_marker, prometheus_install)
            if "pymongo[srv]" not in updated and "dnspython" not in updated:
                pymongo_marker = "RUN pip install django-prometheus==2.3.1"
                pymongo_install = """RUN pip install django-prometheus==2.3.1\n\n# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]" """
                if pymongo_marker in updated:
                    updated = updated.replace(pymongo_marker, pymongo_install)
                else:
                    updated = updated.replace(
                        base_req_marker,
                        base_req_marker + """\n\n# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]" """,
                    )

    if path.name == "production.py":
        updated = ensure_allowed_hosts(updated)
        updated = ensure_csrf_origins(updated)
        updated = force_mfe_discussions_only(updated)
        # Ensure DEFAULT_SITE_THEME is set for fallback branding
        if "DEFAULT_SITE_THEME" not in updated:
            # Add at the end of the file
            updated = updated.rstrip() + '\n\n# Set default theme for all sites\nDEFAULT_SITE_THEME = "mereka"\n'

        # Add custom MFE OAuth fix app
        if "mfe_oauth_fix" not in updated:
            mfe_oauth_fix_config = textwrap.dedent("""

                # MFE OAuth Fix - Custom app to fix OAuth provider visibility
                import sys
                sys.path.insert(0, '/openedx')
                INSTALLED_APPS.append('mfe_oauth_fix')

                # Add middleware to fix /api/mfe_context responses
                # Insert at the end of middleware stack so it processes responses
                MIDDLEWARE.append('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware')
            """).strip()
            updated = updated.rstrip() + '\n\n' + mfe_oauth_fix_config + '\n'

        # Add Prometheus metrics integration
        if "django_prometheus" not in updated:
            prometheus_config = textwrap.dedent("""

                # Prometheus Metrics Integration
                # django_prometheus must be added at the START of INSTALLED_APPS
                if 'django_prometheus' not in INSTALLED_APPS:
                    INSTALLED_APPS.insert(0, 'django_prometheus')

                # Add custom prometheus app for /metrics endpoint
                if 'openedx_prometheus' not in INSTALLED_APPS:
                    INSTALLED_APPS.append('openedx_prometheus')

                # Prometheus middleware must wrap all other middleware
                if 'django_prometheus.middleware.PrometheusBeforeMiddleware' not in MIDDLEWARE:
                    MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
                if 'django_prometheus.middleware.PrometheusAfterMiddleware' not in MIDDLEWARE:
                    MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')
            """).strip()
            updated = updated.rstrip() + '\n\n' + prometheus_config + '\n'

        # Add mereka_tenancy multi-tenancy app
        if "mereka_tenancy" not in updated:
            tenancy_config = textwrap.dedent("""

                # Mereka Multi-Tenancy — tenant model extensions + resolution middleware
                # See: specs/multi-tenancy-architecture_spec.md
                import sys as _mt_sys
                if '/openedx' not in _mt_sys.path:
                    _mt_sys.path.insert(0, '/openedx')
                if 'mereka_tenancy' not in INSTALLED_APPS:
                    INSTALLED_APPS.append('mereka_tenancy')

                # TenantResolutionMiddleware resolves hostname → Site → EnterpriseCustomer
                # Insert after CurrentSiteMiddleware so Site is already resolved.
                if 'mereka_tenancy.middleware.TenantResolutionMiddleware' not in MIDDLEWARE:
                    _site_mw = 'django.contrib.sites.middleware.CurrentSiteMiddleware'
                    if _site_mw in MIDDLEWARE:
                        _idx = MIDDLEWARE.index(_site_mw) + 1
                        MIDDLEWARE.insert(_idx, 'mereka_tenancy.middleware.TenantResolutionMiddleware')
                    else:
                        MIDDLEWARE.append('mereka_tenancy.middleware.TenantResolutionMiddleware')
            """).strip()
            updated = updated.rstrip() + '\n\n' + tenancy_config + '\n'

    if path.name == "env.config.jsx":
        updated = updated.replace("import Footer from '@edly-io/indigo-frontend-component-footer';\n", "")
        css_hook = "import { DIRECT_PLUGIN, PLUGIN_OPERATIONS } from '@openedx/frontend-plugin-framework';\n"
        css_target = css_hook + "import './mereka/mereka.scss';\n"
        if "mereka/mereka.scss" not in updated:
            if css_hook in updated:
                updated = updated.replace(css_hook, css_target)
            else:
                # Some Tutor MFE templates use a simplified env.config.jsx without plugin-framework imports.
                # Still import the theme so authn (and other MFEs) reliably ship branded CSS bundles.
                get_config_import = "import { getConfig } from '@edx/frontend-platform';\n"
                if get_config_import in updated:
                    updated = updated.replace(get_config_import, get_config_import + "import './mereka/mereka.scss';\n", 1)
        footer_component = textwrap.dedent(
            r"""
            const MerekaFooter = () => {
              const config = getConfig();
              const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
              const siteName = config.SITE_NAME || 'Mereka Academy';
              const currentYear = new Date().getFullYear();
              const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
              const logoUrl = baseUrl ? baseUrl + '/static/images/logo.png' : '';

              const SITE_VARIANTS = {
                'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
                'academy.biji-biji.com': { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
                'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
              };
              const variant = SITE_VARIANTS[hostname] || { brand: siteName, copyrightHolder: 'MEREKA', whatsapp: '601135271981' };

              const socialLinks = [
                { name: 'TikTok', url: 'https://www.tiktok.com/@mereka.io', icon: 'M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z' },
                { name: 'Instagram', url: 'https://www.instagram.com/mereka.io/', icon: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z' },
                { name: 'Facebook', url: 'https://www.facebook.com/mereka.io', icon: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z' },
                { name: 'LinkedIn', url: 'https://www.linkedin.com/company/mereka/', icon: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z' },
                { name: 'YouTube', url: 'https://www.youtube.com/channel/UCCyMH5KIZeCMchjMKl7RWxg', icon: 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z' },
              ];

              const navLinks = [
                { label: 'About', url: 'https://corporate.mereka.io/about-us' },
                { label: 'Andragogy', url: 'https://corporate.mereka.io/andragogy' },
                { label: 'Portfolio', url: 'https://corporate.mereka.io/portfolio' },
                { label: 'Team', url: 'https://corporate.mereka.io/our-team' },
                { label: 'Careers', url: 'https://corporate.mereka.io/work-with-us' },
                { label: 'Ecosystem', url: 'https://corporate.mereka.io/ecosystem' },
                { label: 'Blog', url: 'https://corporate.mereka.io/blog' },
                { label: 'Help Centre', url: 'https://help.mereka.io/' },
              ];

              const corporateLinks = [
                { label: 'Accelerate Talent', url: 'https://corporate.mereka.io/academy/funders' },
                { label: 'Create Online Course', url: 'https://corporate.mereka.io/academy/create-online-courses' },
                { label: 'Build a Makerspace', url: 'https://corporate.mereka.io/academy/makerspace' },
              ];

              const marketplaceUserLinks = [
                { label: 'Experiences', url: 'https://mereka.io/experiences' },
                { label: 'Experts', url: 'https://mereka.io/experts' },
                { label: 'Expertise', url: 'https://mereka.io/expertise' },
                { label: 'Hubs', url: 'https://mereka.io/hubs' },
                { label: 'Spaces', url: 'https://corporate.mereka.io/space' },
              ];

              const marketplaceBusinessLinks = [
                { label: 'Pricing', url: 'https://hubs.mereka.io/pricing' },
                { label: 'Solutions', url: 'https://hubs.mereka.io/howitworks' },
              ];

              const academyLinks = [
                { label: 'Future of Work', url: 'https://corporate.mereka.io/academy/future-of-work' },
                { label: 'Digital Entrepreneur', url: 'https://corporate.mereka.io/academy/digital-entrepreneur' },
                { label: 'All Courses', url: 'https://corporate.mereka.io/academy/all-courses' },
              ];

              const spaceLinks = [
                { label: 'Mereka @ Publika', url: 'https://corporate.mereka.io/publika' },
                { label: 'Our Labs', url: 'https://corporate.mereka.io/space#labs' },
                { label: 'Bespoke Design', url: 'https://corporate.mereka.io/space/innovate#products' },
                { label: 'Host Events', url: 'https://corporate.mereka.io/space#event-cta' },
              ];

              const SocialIcon = ({ d }) => (
                <svg style={{ width: '20px', height: '20px' }} fill="currentColor" viewBox="0 0 24 24"><path d={d} /></svg>
              );

              const WhatsAppIcon = () => (
                <svg style={{ width: '20px', height: '20px', color: '#25D366' }} fill="currentColor" viewBox="0 0 24 24">
                  <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
                </svg>
              );

              return (
                <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
                  {/* Zone 1: Social Row */}
                  <div className="footer-social">
                    <div className="footer-container">
                      <a href={baseUrl || '/'} className="footer-logo-link">
                        {logoUrl ? <img src={logoUrl} alt={variant.brand + ' logo'} className="footer-logo-img" /> : null}
                        <span className="footer-brand-name">mereka</span>
                      </a>
                      <div className="footer-social-icons">
                        {socialLinks.map(s => (
                          <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                            <SocialIcon d={s.icon} />
                          </a>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Zone 2: Nav Strip */}
                  <div className="footer-nav">
                    <div className="footer-container">
                      <nav className="footer-nav-links">
                        {navLinks.map(l => (
                          <a key={l.label} href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a>
                        ))}
                      </nav>
                      <a href={'https://wa.me/' + variant.whatsapp} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
                        <WhatsAppIcon /> Contact Us
                      </a>
                    </div>
                  </div>

                  {/* Zone 3: 4-Column Body */}
                  <div className="footer-body">
                    <div className="footer-container footer-columns">
                      <div className="footer-column">
                        <h4 className="footer-column-title">Corporate</h4>
                        <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                      </div>
                      <div className="footer-column footer-column--wide">
                        <h4 className="footer-column-title">Marketplace</h4>
                        <div className="footer-marketplace-grid">
                          <div>
                            <p className="footer-sub-heading">USERS</p>
                            <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                          </div>
                          <div>
                            <p className="footer-sub-heading">BUSINESS</p>
                            <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                            <p className="footer-app-label">Manage your bookings</p>
                            <div className="footer-app-badges">
                              <a href="https://apps.apple.com/id/app/mereka-hubs/id6473277964" target="_blank" rel="noopener noreferrer" className="footer-badge">App Store</a>
                              <a href="https://play.google.com/store/apps/details?id=io.mereka.hubs" target="_blank" rel="noopener noreferrer" className="footer-badge">Google Play</a>
                            </div>
                            <a href="https://mereka.io/welcome/hub" target="_blank" rel="noopener noreferrer" className="footer-cta-btn">Become a Hub</a>
                          </div>
                        </div>
                      </div>
                      <div className="footer-column">
                        <h4 className="footer-column-title">Academy</h4>
                        <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                      </div>
                      <div className="footer-column">
                        <h4 className="footer-column-title">Space</h4>
                        <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                      </div>
                    </div>
                  </div>

                  {/* Zone 4: Legal Bottom */}
                  <div className="footer-legal">
                    <div className="footer-container footer-legal-row">
                      <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
                      <a href="https://legal.mereka.io/" target="_blank" rel="noopener noreferrer">TERMS OF USE</a>
                      <a href="https://legal.mereka.io/privacy-policy/" target="_blank" rel="noopener noreferrer">PRIVACY POLICY</a>
                      <a href="https://legal.mereka.io/#cookie-policy" target="_blank" rel="noopener noreferrer">COOKIES POLICY</a>
                    </div>
                  </div>
                </footer>
              );
            };
            """
        ).strip()
        if "const MerekaFooter" not in updated:
            updated = updated.replace("const themePluginSlot =", footer_component + "\n\nconst themePluginSlot =", 1)
        # MIGRATED-TO-SLOT: footer_slot
        # Primary path: mereka_lms.py plugin slot wiring (PLUGIN_SLOTS.add_item footer_slot with RenderWidget: <MerekaFooter />)
        # Fallback path: apply-patches.sh injects MerekaFooter component definition so env.config.jsx
        #   can reference: { RenderWidget: <MerekaFooter /> } within themePluginSlot footer_slot entry.
        # Rollback: revert mereka_lms.py PLUGIN_SLOTS entry and this patch block; restore IndigoFooter.
        if "RenderWidget: <MerekaFooter />" not in updated and "const MerekaFooter" in updated:
            # Fallback: wire MerekaFooter into the themePluginSlot footer_slot entry if plugin didn't render it
            updated = updated.replace(
                "RenderWidget: IndigoFooter,",
                "RenderWidget: <MerekaFooter />,  // MIGRATED-TO-SLOT: footer_slot (fallback)",
                1,
            )

    if path.name == "lms.conf":
        anchor = "  server_name academyv2.mereka.io preview.academyv2.mereka.io;"
        if anchor in updated and "academy.biji-biji.com" not in updated:
            updated = updated.replace(
                anchor,
                anchor.rstrip(";")
                + " academy.biji-biji.com skillourfuture.academy.mereka.io;",
            )
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
        # Add /metrics endpoint (internal access only, for Prometheus scraping)
        if "location = /metrics" not in updated:
            metrics_block = (
                "  # Prometheus metrics endpoint (internal access only)\n"
                "  location = /metrics {\n"
                "    proxy_set_header Host $http_host;\n"
                "    proxy_redirect off;\n"
                "    proxy_pass http://lms-backend;\n"
                "  }\n\n"
            )
            marker = "  location = /health {"
            if marker in updated:
                updated = updated.replace(marker, metrics_block + marker, 1)
        if "apps.academyv2.mereka.io" in updated and "/profile/api/" not in updated:
            pattern = re.compile(
                r"(server_name apps\.academyv2\.mereka\.io;.*?)(\n  location / \{)",
                re.S,
            )
            profile_proxy = (
                "  location ^~ /profile/api/ {\n"
                "    proxy_set_header Host academyv2.mereka.io;\n"
                "    proxy_redirect off;\n"
                "    proxy_pass http://lms-backend;\n"
                "  }\n\n"
            )
            updated = pattern.sub(rf"\\1\n{profile_proxy}\\2", updated, count=1)
    if path.name == "Caddyfile":
        # For extra LMS hosts, use the proper LMS proxy pattern (not nginx)
        lms_caddy_block_template = """__DOMAIN__{$default_site_port} {
    @favicon_matcher {
        path_regexp ^/favicon.ico$
    }
    rewrite @favicon_matcher /theming/asset/images/favicon.ico

    # Limit profile image upload size
    handle_path /api/profile_images/*/*/upload {
        request_body {
            max_size 1MB
        }
    }

    import proxy "lms:8000"

    handle_path /* {
        request_body {
            max_size 4MB
        }
    }
}

"""
        for host in extra_lms_hosts:
            if host not in updated:
                updated = updated.rstrip() + "\n\n" + lms_caddy_block_template.replace("__DOMAIN__", host)
        if "apps.academyv2.mereka.io" in updated and "/profile/api/" not in updated:
            needle = "apps.academyv2.mereka.io {\n        reverse_proxy nginx:80"
            replacement = (
                "apps.academyv2.mereka.io {\n"
                "        reverse_proxy /profile/api/* lms:8000 {\n"
                "            header_up Host academyv2.mereka.io\n"
                "        }\n"
                "        reverse_proxy nginx:80"
            )
            updated = updated.replace(needle, replacement, 1)

    # Disable django-pipeline UglifyJS compression during collectstatic.
    # UglifyJS v2.6.1 cannot parse ES6+ syntax (arrow functions, template literals).
    # Setting JS_COMPRESSOR to None still concatenates JS but skips minification.
    # CMS already has this set by default; only LMS enables UglifyJS.
    if path.name == "assets.py" and "derive_settings" in updated:
        pipeline_patch = "PIPELINE['JS_COMPRESSOR'] = None\n"
        if "JS_COMPRESSOR" not in updated:
            updated = updated.rstrip() + "\n\n" + pipeline_patch

    # Fix collectstatic SuspiciousFileOperation in v21 asset builds.
    # The theming storage's safe_join fails on relative CSS paths that resolve outside STATIC_ROOT.
    # Monkey-patch safe_join in the canonical module AND in every module that already imported it
    # (e.g. django.core.files.storage.filesystem imports safe_join at module level).
    if path.name == "assets.py" and "derive_settings" in updated:
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

    if updated != original:
        path.write_text(updated)
PY

MFE_INDIGO_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo"
if [ -d "$MFE_INDIGO_DIR" ]; then
  mkdir -p "$MFE_INDIGO_DIR/mereka"
  rm -rf "$MFE_INDIGO_DIR/mereka/scss"
  cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/scss" "$MFE_INDIGO_DIR/mereka/scss"
  rm -rf "$MFE_INDIGO_DIR/mereka/fonts"
  cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts" "$MFE_INDIGO_DIR/mereka/fonts"
  cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss" "$MFE_INDIGO_DIR/mereka/mereka.scss"
fi

# Tutor's MFE plugin uses a top-level env.config.jsx as the webpack entry adjunct for all MFEs.
# Ensure it imports our theme so authn (and other MFEs) reliably ship branded CSS bundles.
MFE_ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
if [ -f "$MFE_ENV_CONFIG" ] && ! grep -q "mereka/mereka.scss" "$MFE_ENV_CONFIG"; then
  python - "$MFE_ENV_CONFIG" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="ignore")
if "mereka/mereka.scss" in text:
    raise SystemExit(0)

needle = "import { getConfig } from '@edx/frontend-platform';\n"
insertion = needle + "import './mereka/mereka.scss';\n"
if needle in text:
    text = text.replace(needle, insertion, 1)
else:
    # Fallback: append after the first import block.
    lines = text.splitlines(True)
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if not inserted and line.startswith("import ") and line.rstrip().endswith(";"):
            continue
        if not inserted and not line.startswith("import "):
            out.insert(len(out) - 1, "import './mereka/mereka.scss';\n")
            inserted = True
    text = "".join(out)

path.write_text(text, encoding="utf-8")
PY
fi

# Normalize any historical duplicate inserts (keep a single import next to getConfig).
if [ -f "$MFE_ENV_CONFIG" ]; then
  python - "$MFE_ENV_CONFIG" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines(True)
import_line = "import './mereka/mereka.scss';\n"
cleaned = [ln for ln in lines if ln != import_line]

needle = "import { getConfig } from '@edx/frontend-platform';\n"
out = []
inserted = False
for ln in cleaned:
    out.append(ln)
    if not inserted and ln == needle:
        out.append(import_line)
        inserted = True

if not inserted:
    # Place after the last import if getConfig wasn't found.
    out2 = []
    last_import_idx = -1
    for idx, ln in enumerate(out):
        out2.append(ln)
        if ln.startswith("import "):
            last_import_idx = idx
    if last_import_idx >= 0:
        out2.insert(last_import_idx + 1, import_line)
        out = out2
    else:
        out.insert(0, import_line)

path.write_text("".join(out), encoding="utf-8")
PY
fi

# MFE Dockerfile patching is handled by the Python patch phase above.

# Sync all logo files from theme source to build directory
echo "Syncing logo files from theme source to build directory..."
THEME_BUILD_DIR="$REPO_ROOT/tutor_env/env/build/openedx/themes/mereka"
if [ -d "$THEME_BUILD_DIR" ]; then
  # Copy all logo variants to LMS static images
  mkdir -p "$THEME_BUILD_DIR/lms/static/images"
  for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                   logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                   favicon.ico; do
    src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images/$logo_file"
    if [ -f "$src_file" ]; then
      cp "$src_file" "$THEME_BUILD_DIR/lms/static/images/$logo_file"
      echo "  ✓ Copied $logo_file to LMS theme"
    fi
  done

  # Copy to CMS static images if CMS theme exists
  if [ -d "$THEME_BUILD_DIR/cms" ]; then
    mkdir -p "$THEME_BUILD_DIR/cms/static/images"
    for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                     logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                     favicon.ico; do
      src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images/$logo_file"
      if [ -f "$src_file" ]; then
        cp "$src_file" "$THEME_BUILD_DIR/cms/static/images/$logo_file"
        echo "  ✓ Copied $logo_file to CMS theme"
      fi
    done
  fi
  echo "Logo files synced successfully."

  # Copy font assets into the build theme dirs so collectstatic picks them up
  echo "Syncing font files from theme source to build directory..."
  mkdir -p "$THEME_BUILD_DIR/lms/static/fonts"
  if compgen -G "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts/*.woff2" >/dev/null; then
    cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts/"*.woff2 "$THEME_BUILD_DIR/lms/static/fonts/"
    echo "  ✓ Copied fonts to LMS theme"
  else
    echo "  ⚠ No LMS fonts found to copy"
  fi

  if [ -d "$THEME_BUILD_DIR/cms" ]; then
    mkdir -p "$THEME_BUILD_DIR/cms/static/fonts"
    if compgen -G "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts/*.woff2" >/dev/null; then
      cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts/"*.woff2 "$THEME_BUILD_DIR/cms/static/fonts/"
      echo "  ✓ Copied fonts to CMS theme"
    else
      echo "  ⚠ No CMS fonts found to copy"
    fi
  fi

  # Keep build context in lockstep with repo theme sources (prevents "it works locally
  # but not in the built image" drift when we add new templates/static dirs).
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
  echo "⚠ Warning: Theme build directory not found. Logo sync skipped."
fi

# Sync custom apps into build context for openedx image
CUSTOM_APPS_SRC="$REPO_ROOT/infrastructure/tutor/custom-apps"
CUSTOM_APPS_DEST="$REPO_ROOT/tutor_env/env/build/openedx/infrastructure/tutor/custom-apps"
if [ -d "$CUSTOM_APPS_SRC" ] && [ -d "$REPO_ROOT/tutor_env/env/build/openedx" ]; then
  mkdir -p "$CUSTOM_APPS_DEST"
  cp -R "$CUSTOM_APPS_SRC/." "$CUSTOM_APPS_DEST/"
  echo "Custom apps synced to build context."
else
  echo "⚠ Warning: Custom apps sync skipped (missing build context)."
fi

# Sync multi-tenancy plugin into build context for openedx image
TENANCY_PLUGIN_SRC="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy"
TENANCY_PLUGIN_DEST="$REPO_ROOT/tutor_env/env/build/openedx/infrastructure/tutor/plugins/multi-tenancy"
if [ -d "$TENANCY_PLUGIN_SRC" ] && [ -d "$REPO_ROOT/tutor_env/env/build/openedx" ]; then
  mkdir -p "$(dirname "$TENANCY_PLUGIN_DEST")"
  cp -R "$TENANCY_PLUGIN_SRC" "$TENANCY_PLUGIN_DEST"
  echo "Multi-tenancy plugin synced to build context."
else
  echo "⚠ Warning: Multi-tenancy plugin sync skipped (missing build context)."
fi

echo "Applied local Tutor patches."
