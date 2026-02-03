#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/.venv/bin/activate"

MFE_TEMPLATE=$(python - <<'PY'
import inspect
import tutormfe
from pathlib import Path
print(Path(inspect.getfile(tutormfe)) / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
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
    caddy_block_template = """{domain} {{
    reverse_proxy nginx:80 {{
        header_up X-Forwarded-Port 443
    }}
}}

"""

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
        "# Redwood skips manual compilejsi18n while content libraries mature.\n",
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
    updated = updated.replace(
        'RUN if [ ! -f /openedx/edx-platform/lms/static/css/lms-main.css ]; then npm run compile-sass -- --skip-themes; else echo "compile-sass skipped (prebuilt assets)"; fi',
        "RUN npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka && npm run compile-sass -- --skip-themes",
    )
    updated = updated.replace(
        'RUN if [ ! -f /openedx/edx-platform/common/static/bundles/commons.js ]; then npm run webpack; else echo "webpack skipped (prebuilt bundles)"; fi',
        "RUN npm run webpack",
    )
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

    if path.name == "production.py":
        updated = ensure_allowed_hosts(updated)
        updated = ensure_csrf_origins(updated)

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
              const logoUrl = baseUrl ? `${baseUrl}/static/mereka/images/logo-horizontal.png` : '';

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
        for host in extra_lms_hosts:
            if host not in updated:
                updated = updated.rstrip() + "\n\n" + caddy_block_template.format(domain=host)
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

# Patch MFE Dockerfile to copy mereka folder into Docker build
MFE_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
if [ -f "$MFE_DOCKERFILE" ]; then
  echo "Patching MFE Dockerfile to include Mereka branding..."
  # Add COPY command for mereka folder after each env.config.jsx copy
  sed -i 's|COPY indigo/env.config.jsx /openedx/app/|COPY indigo/env.config.jsx /openedx/app/\nCOPY indigo/mereka /openedx/app/mereka|g' "$MFE_DOCKERFILE"
  echo "MFE Dockerfile patched."
fi

echo "Applied local Tutor patches."
