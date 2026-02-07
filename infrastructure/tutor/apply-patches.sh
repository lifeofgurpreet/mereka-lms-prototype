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

FORUM_ENTRYPOINT_TEMPLATE=$(python - <<'PY'
from pathlib import Path
import tutor
print(Path(tutor.__file__).parent / "templates" / "apps" / "forum" / "bin" / "docker-entrypoint.sh")
PY
)

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
print(Path(tutor.__file__).parent / "templates" / "apps" / "openedx" / "settings" / "lms" / "assets.py")
PY
)

FORUM_PLUGIN=$(python - <<'PY'
from pathlib import Path
import tutorforum
print(Path(tutorforum.__file__).parent / "plugin.py")
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
  "$FORUM_ENTRYPOINT_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/forum/bin/docker-entrypoint.sh"
  "$CADDY_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile"
  "$NGINX_LMS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf"
  "$LMS_SETTINGS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
  "$LMS_ASSETS_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/settings/lms/assets.py"
  "$WEBPACK_PROD_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/build/openedx/edx-platform/webpack.prod.config.js"
  "$FORUM_PLUGIN"
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
    if path.name == "plugin.py" and 'DD_TRACE_ENABLED' not in updated:
        needle = '"MONGOID_USE_SSL": "{{ \'true\' if MONGODB_USE_SSL else \'false\' }}",'
        if needle in updated:
            updated = updated.replace(
                needle,
                needle
                + '\n    "DD_TRACE_ENABLED": "false",',
            )
    extra_lms_hosts = [
        "academy.biji-biji.com",
        "skillourfuture.academy.mereka.io",
    ]
    extra_csrf_origins = [
        "https://academy.biji-biji.com",
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
        if "npm clean-install attempt ${attempt} failed" in text:
            return text
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
            " && bash -o pipefail -c 'for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo \"npm clean-install attempt ${attempt} failed; retrying in 15s\" >&2; sleep 15; done; exit 1'"
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
            " && bash -o pipefail -c 'for attempt in 1 2 3; do npm clean-install --no-audit --registry=$NPM_REGISTRY && exit 0; echo \"npm clean-install attempt ${attempt} failed; retrying in 15s\" >&2; sleep 15; done; exit 1'",
            text,
        )

    # Ensure MFEs build against Node 18 with the required toolchain.
    if "docker.io/node:12-bullseye-slim" in updated:
        updated = updated.replace(
            "FROM docker.io/node:12-bullseye-slim",
            "FROM docker.io/node:18-bullseye-slim",
        )
    if "gcc git libgl1 libxi6 make" in updated:
        updated = updated.replace(
            "gcc git libgl1 libxi6 make",
            "gcc g++ git libgl1 libxi6 make python3 python3-distutils",
        )

    updated = ensure_mfe_cookie_env(updated)
    updated = ensure_mfe_theme_copy(updated)
    updated = ensure_mfe_npm_resilience(updated)

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
    env_replacement = "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\nENV PYTHONPATH=/openedx/edx-platform\nENV NODE_OPTIONS=\"--max-old-space-size=6144\"\nWORKDIR /openedx/edx-platform\n"
    updated = updated.replace(env_block_spaces, env_replacement)
    updated = updated.replace(env_block_equals, env_replacement)
    updated = updated.replace(
        env_block_short,
        "ENV PATH=/openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV=/openedx/venv/\nENV PYTHONPATH=/openedx/edx-platform\nENV NODE_OPTIONS=\"--max-old-space-size=6144\"\n",
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

    # Add custom apps to Dockerfile
    if path.name == "Dockerfile" and "/openedx/edx-platform" in updated:
        # Find the line where we copy themes and add our custom apps after it
        copy_themes_marker = "COPY --chown=app:app themes/ /openedx/themes/"
        copy_themes_marker_alt = "COPY --chown=app:app ./themes/ /openedx/themes"
        custom_apps_block = """# Copy custom apps
COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus"""
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
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus"""
            updated = updated.replace(mfe_oauth_marker, custom_apps_add)
        elif "mfe_oauth_fix" not in updated and "openedx_prometheus" not in updated:
            # If themes copy doesn't exist, add before WORKDIR /openedx/edx-platform
            workdir_marker = "WORKDIR /openedx/edx-platform\n"
            if workdir_marker in updated:
                custom_app_insert = f"""# Copy custom apps
COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus

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

    if path.name == "env.config.jsx":
        updated = updated.replace("import Footer from '@edly-io/indigo-frontend-component-footer';\n", "")
        css_hook = "import { DIRECT_PLUGIN, PLUGIN_OPERATIONS } from '@openedx/frontend-plugin-framework';\n"
        css_target = css_hook + "import './mereka/mereka.scss';\n"
        if "mereka/mereka.scss" not in updated:
            updated = updated.replace(css_hook, css_target)
        footer_component = textwrap.dedent(
            r"""
            const MerekaFooter = () => {
              const config = getConfig();
              const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
              const siteName = config.SITE_NAME || 'Mereka Academy';
              const coursesUrl = baseUrl ? `${baseUrl}/courses` : '/courses';
              const dashboardUrl = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
              const supportEmail = config.CONTACT_EMAIL || 'team@mereka.io';
              const supportLink = `mailto:${supportEmail}`;
              const currentYear = new Date().getFullYear();
              const logoUrl = baseUrl ? `${baseUrl}/static/images/logo.png` : '';

              return (
                <footer className="mereka-footer" role="contentinfo">
                  <div className="container-xl footer-primary">
                    <div className="footer-brand">
                      {logoUrl ? <img src={logoUrl} alt={`${siteName} logo`} /> : null}
                      <p>
                        Mereka Academy blends community, craftsmanship, and technology to help learners master
                        the creative, digital, and entrepreneurial skills powering Southeast Asia.
                      </p>
                      <div className="footer-tags">
                        <span>Future of Work</span>
                        <span>Creative Tech</span>
                        <span>Impact</span>
                      </div>
                    </div>
                    <div className="footer-links">
                      <h6>Explore</h6>
                      <ul>
                        <li><a href={coursesUrl}>Courses</a></li>
                        <li><a href={dashboardUrl}>My learning</a></li>
                        <li><a href="https://mereka.my" target="_blank" rel="noopener">Mereka main site</a></li>
                        <li><a href="mailto:team@mereka.io">team@mereka.io</a></li>
                      </ul>
                    </div>
                    <div className="footer-links">
                      <h6>Support</h6>
                      <ul>
                        <li><a href="mailto:techadmin@biji-biji.com">techadmin@biji-biji.com</a></li>
                        <li><a href={supportLink}>{supportEmail}</a></li>
                        <li><a href="https://academyv2.mereka.io/help" target="_blank" rel="noopener">Help centre</a></li>
                        <li><a href="https://academyv2.mereka.io/privacy" target="_blank" rel="noopener">Privacy</a></li>
                      </ul>
                    </div>
                    <div className="footer-links">
                      <h6>Partners</h6>
                      <ul>
                        <li><a href="https://biji-biji.com" target="_blank" rel="noopener">Biji-Biji Initiative</a></li>
                        <li><a href="https://mereka.my/partner" target="_blank" rel="noopener">Partner with us</a></li>
                        <li><a href="https://mereka.my/stories" target="_blank" rel="noopener">Stories</a></li>
                      </ul>
                    </div>
                  </div>
                  <div className="footer-bottom container-xl">
                    <span>© {currentYear} Biji-Biji Initiative · {siteName}</span>
                    <span>Powered by Open edX &amp; Tutor</span>
                  </div>
                </footer>
              );
            };
            """
        ).strip()
        if "const MerekaFooter" not in updated:
            updated = updated.replace("const themePluginSlot =", footer_component + "\n\nconst themePluginSlot =", 1)
        updated = updated.replace("RenderWidget: <Footer />", "RenderWidget: <MerekaFooter />")

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
        lms_caddy_block_template = """{domain}{{{{$default_site_port}}}} {{
    @favicon_matcher {{
        path_regexp ^/favicon.ico$
    }}
    rewrite @favicon_matcher /theming/asset/images/favicon.ico

    # Limit profile image upload size
    handle_path /api/profile_images/*/*/upload {{
        request_body {{
            max_size 1MB
        }}
    }}

    import proxy "lms:8000"

    handle_path /* {{
        request_body {{
            max_size 4MB
        }}
    }}
}}

"""
        for host in extra_lms_hosts:
            if host not in updated:
                updated = updated.rstrip() + "\n\n" + lms_caddy_block_template.format(domain=host)
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

echo "Applied local Tutor patches."
