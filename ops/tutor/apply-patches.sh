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

PATCH_TARGETS=(
  "$MFE_TEMPLATE"
  "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
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
)

python - "${PATCH_TARGETS[@]}" <<'PY'
from pathlib import Path
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original
    extra_lms_hosts = [
        "academy.biji-biji.com",
        "skillourfuture.staging.academy.mereka.io",
    ]
    extra_csrf_origins = [
        "https://academy.biji-biji.com",
        "https://skillourfuture.staging.academy.mereka.io",
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
        anchor = 'CSRF_TRUSTED_ORIGINS.append("apps.staging.academy.mereka.io")'
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
        "# Re-install local requirements, otherwise egg-info folders are missing\nRUN pip install -r requirements/edx/local.in\n\n",
        "# Local requirements list removed in Redwood; skip redundant reinstall step.\n",
    )
    updated = updated.replace(
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\n',
        'INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")\n# Mereka adjustments keep Redwood optional apps enabled\nDATABASE_ROUTERS.remove(\n    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"\n)\nif "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]\nif "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]\nif "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]\nif "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:\n    INSTALLED_APPS += [\"openedx.core.djangoapps.theming.apps.ThemingConfig\"]\n',
    )
    updated = updated.replace(
        "ENV PATH /openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV /openedx/venv/\nWORKDIR /openedx/edx-platform\n",
        "ENV PATH /openedx/venv/bin:./node_modules/.bin:/openedx/nodeenv/bin:${PATH}\nENV VIRTUAL_ENV /openedx/venv/\nENV PYTHONPATH=/openedx/edx-platform\nWORKDIR /openedx/edx-platform\n",
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
        "RUN openedx-assets xmodule \\\n    && openedx-assets npm \\\n    && openedx-assets webpack --env=prod \\\n    && openedx-assets common\n",
        "RUN npm run postinstall\n",
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

    if path.name == "lms.conf" and "academy.biji-biji.com" not in updated:
        anchor = "  server_name staging.academy.mereka.io preview.staging.academy.mereka.io;"
        if anchor in updated:
            updated = updated.replace(
                anchor,
                anchor.rstrip(";")
                + " academy.biji-biji.com skillourfuture.staging.academy.mereka.io;",
            )
    if path.name == "Caddyfile":
        for host in extra_lms_hosts:
            if host not in updated:
                updated = updated.rstrip() + "\n\n" + caddy_block_template.format(domain=host)

    if updated != original:
        path.write_text(updated)
PY

echo "Applied local Tutor patches."
