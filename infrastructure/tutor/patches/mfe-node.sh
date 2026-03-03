#!/usr/bin/env bash
# Patch: MFE Node 24.11.0 base image, toolchain, cookie env, theme copy,
#        npm resilience, plugin framework, admin-console redux, course-authoring fix,
#        new relic env, ulmo source refs, brand version, discussions webpack fix.

apply_mfe_node_patch() {
  local targets=(
    "$MFE_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    def ensure_mfe_cookie_env(text):
        marker = "ENV MFE_CONFIG_API_URL=/api/mfe_config/v1"
        # Normalize historical hardcoded defaults to empty values so cookie domains
        # are provided by runtime config/environment, not baked into the image.
        text = text.replace(
            "ARG SESSION_COOKIE_DOMAIN=.academyv2.mereka.io",
            'ARG SESSION_COOKIE_DOMAIN=""',
        )
        text = text.replace(
            "ARG CSRF_COOKIE_DOMAIN=.academyv2.mereka.io",
            'ARG CSRF_COOKIE_DOMAIN=""',
        )
        text = text.replace(
            "ARG SESSION_COOKIE_DOMAIN=.localhost",
            'ARG SESSION_COOKIE_DOMAIN=""',
        )
        text = text.replace(
            "ARG CSRF_COOKIE_DOMAIN=.localhost",
            'ARG CSRF_COOKIE_DOMAIN=""',
        )

        if marker not in text:
            return text
        if "SESSION_COOKIE_DOMAIN" in text:
            return text
        cookie_block = (
            "ENV MFE_CONFIG_API_URL=/api/mfe_config/v1\n"
            'ARG SESSION_COOKIE_DOMAIN=""\n'
            'ARG CSRF_COOKIE_DOMAIN=""\n'
            "ENV SESSION_COOKIE_DOMAIN=${SESSION_COOKIE_DOMAIN}\n"
            "ENV CSRF_COOKIE_DOMAIN=${CSRF_COOKIE_DOMAIN}"
        )
        return text.replace(marker, cookie_block)

    def ensure_mfe_theme_copy(text):
        env_copy = "COPY indigo/env.config.jsx /openedx/app/"
        app_theme_copy = "COPY indigo/mereka /openedx/app/mereka"
        runtime_theme_copy = "COPY indigo/theme /openedx/dist/theme"
        runtime_brand_copy = "COPY indigo/brand-mereka /openedx/brand-mereka"
        runtime_brand_assets_copy = (
            "RUN mkdir -p /openedx/dist/theme \\\n"
            " && cp -f /openedx/brand-mereka/favicon.ico /openedx/dist/theme/favicon.ico \\\n"
            " && cp -f /openedx/brand-mereka/logo.png /openedx/dist/theme/logo-horizontal.png \\\n"
            " && cp -f /openedx/brand-mereka/logo.svg /openedx/dist/theme/logo-horizontal.svg \\\n"
            " && cp -f /openedx/brand-mereka/logo-white.png /openedx/dist/theme/logo-horizontal-white.png \\\n"
            " && cp -f /openedx/brand-mereka/logo-white.svg /openedx/dist/theme/logo-horizontal-white.svg \\\n"
            " && cp -f /openedx/brand-mereka/logo-trademark.png /openedx/dist/theme/logo.png \\\n"
            " && cp -f /openedx/brand-mereka/logo-trademark.svg /openedx/dist/theme/logo.svg"
        )

        # Remove legacy pre-runtime logo copy blocks from intermediate stages.
        # They do not survive into the final caddy runtime image and create noise.
        text = re.sub(
            r"\nRUN mkdir -p /openedx/dist/static/images \\\n"
            r"(?:\s*&& cp -f /openedx/app/brand-mereka/[^\n]+\n)+",
            "\n",
            text,
        )

        lines = text.splitlines()
        normalized = []
        index = 0
        while index < len(lines):
            line = lines[index]
            normalized.append(line)
            if line.strip() == env_copy:
                next_index = index + 1
                while next_index < len(lines) and lines[next_index].strip() == app_theme_copy:
                    next_index += 1
                normalized.append(app_theme_copy)
                index = next_index
                continue
            index += 1

        lines = normalized

        base_anchor = "WORKDIR /openedx/app"
        has_global_copy = any(line.strip() == app_theme_copy for line in lines[:50])
        if base_anchor in text and not has_global_copy:
            patched = []
            inserted = False
            for line in lines:
                patched.append(line)
                if not inserted and line.strip() == base_anchor:
                    patched.append(app_theme_copy)
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
            has_theme_copy = any(line.strip() == app_theme_copy for line in authn_block)

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
                        inserts.append(app_theme_copy)
                    lines = lines[:insert_at] + inserts + lines[insert_at:]

        # Ensure runtime theme assets are present in the final caddy image.
        # Without this COPY, /theme/*.css resolves to 404 at runtime.
        production_start = None
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("FROM ") and stripped.endswith(" AS production"):
                production_start = idx
                break
        if production_start is not None:
            production_end = len(lines)
            for idx in range(production_start + 1, len(lines)):
                if lines[idx].strip().startswith("FROM "):
                    production_end = idx
                    break
            production_block = lines[production_start:production_end]
            has_runtime_theme_copy = any(
                line.strip() == runtime_theme_copy for line in production_block
            )
            has_runtime_brand_copy = any(
                line.strip() == runtime_brand_copy for line in production_block
            )
            has_runtime_brand_assets_copy = any(
                "/openedx/dist/theme/logo-horizontal.svg" in line for line in production_block
            )
            if not has_runtime_theme_copy:
                insert_at = None
                for idx in range(production_start, production_end):
                    if lines[idx].strip() == "RUN mkdir -p /openedx/dist":
                        insert_at = idx + 1
                        break
                if insert_at is None:
                    insert_at = production_start + 1
                lines = lines[:insert_at] + [runtime_theme_copy] + lines[insert_at:]
                production_end += 1
            if not has_runtime_brand_copy:
                insert_at = None
                for idx in range(production_start, production_end):
                    if lines[idx].strip() == runtime_theme_copy:
                        insert_at = idx + 1
                        break
                if insert_at is None:
                    insert_at = production_start + 1
                lines = lines[:insert_at] + [runtime_brand_copy] + lines[insert_at:]
                production_end += 1
            if not has_runtime_brand_assets_copy:
                insert_at = None
                for idx in range(production_start, production_end):
                    if lines[idx].strip() == runtime_brand_copy:
                        insert_at = idx + 1
                        break
                if insert_at is None:
                    insert_at = production_start + 1
                lines = lines[:insert_at] + [runtime_brand_assets_copy] + lines[insert_at:]

        rebuilt = "\n".join(lines)
        if text.endswith("\n"):
            rebuilt += "\n"
        return rebuilt

    def ensure_mfe_npm_resilience(text):
        if "npm clean-install" not in text:
            return text
        if "npm clean-install attempt ${attempt} failed; attempting npm install fallback" in text:
            if 'echo \\"' in text or '\\" >&2;' in text:
                text = text.replace('echo \\"', 'echo "')
                text = text.replace('\\" >&2;', '" >&2;')
            return text

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
        local_brand_line = "RUN npm install --legacy-peer-deps @edx/brand@file:./brand-mereka"
        legacy_brand_patterns = (
            r"RUN npm install '@edx/brand@npm:@edly-io/indigo-brand-openedx@\^[^']+'",
            r"RUN npm install '@edx/brand@github:@edly-io/brand-openedx#[^']+'",
        )

        for pattern in legacy_brand_patterns:
            text = re.sub(pattern, local_brand_line, text)

        if legacy_line in text:
            text = text.replace(legacy_line, plugin_line)
        if plugin_line in text and local_brand_line in text:
            return text

        if local_brand_line in text or plugin_line in text:
            return text

        return text

    def ensure_mfe_admin_console_redux_deps(text):
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
                lines.insert(idx + 1, redux_line)
                rebuilt = "\n".join(lines)
                if text.endswith("\n"):
                    rebuilt += "\n"
                return rebuilt

        return text

    def ensure_mfe_course_authoring_directory_fix(text):
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

        end = len(lines)
        for idx in range(start + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("######## ") or stripped.startswith("FROM "):
                end = idx
                break

        for idx in range(start, end):
            if "WORKDIR /openedx/app" in lines[idx]:
                symlink_cmd = "RUN ln -sf /openedx/app/frontend-app-course-authoring /openedx/app/course-authoring || true"
                lines.insert(idx + 1, symlink_cmd)
                break

        rebuilt = "\n".join(lines)
        if text.endswith("\n"):
            rebuilt += "\n"
        return rebuilt

    def ensure_mfe_new_relic_env(text):
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

    def ensure_mfe_ulmo_source_refs(text):
        if "mfe/build/mfe/Dockerfile" not in str(path):
            return text
        if "open-release/redwood.3" in text:
            text = re.sub(
                r"(ADD --keep-git-dir=true https://github\.com/openedx/[^\s]+\.git)#open-release/redwood\.3",
                r"\1#release/ulmo.1",
                text,
            )
            text = text.replace(
                "--revision=open-release/redwood.3 ",
                "--revision=release/ulmo.1 ",
            )
            text = text.replace(
                "--revision=open-release/ulmo.1 ",
                "--revision=release/ulmo.1 ",
            )
            # openedx-translations tracks Ulmo on release/ulmo (not release/ulmo.1).
            # Keep translation pulls pinned to the canonical translation branch.
            text = text.replace(
                "--repository=openedx/openedx-translations --revision=open-release/redwood.3 ",
                "--repository=openedx/openedx-translations --revision=release/ulmo ",
            )
            text = text.replace(
                "--repository=openedx/openedx-translations --revision=release/ulmo.1 ",
                "--repository=openedx/openedx-translations --revision=release/ulmo ",
            )
            text = text.replace(
                "--repository=openedx/openedx-translations --revision=open-release/ulmo.1 ",
                "--repository=openedx/openedx-translations --revision=release/ulmo ",
            )
        # frontend-app-admin-console publishes Ulmo on branch `release/ulmo`.
        # Use the branch ref (not the tag) to avoid ref-resolution drift in Docker ADD.
        text = text.replace(
            "frontend-app-admin-console.git#release/ulmo.1",
            "frontend-app-admin-console.git#release/ulmo",
        )
        return text

    def ensure_mfe_brand_ulmo_version(text):
        if "mfe/build/mfe/Dockerfile" not in str(path):
            return text
        text = text.replace(
            "@edly-io/indigo-brand-openedx@^2.1.1",
            "@edly-io/indigo-brand-openedx@^2.4.3",
        )
        return text

    def ensure_mfe_discussions_webpack_noninteractive(text):
        if "mfe/build/mfe/Dockerfile" not in str(path):
            return text
        if "frontend-app-discussions" not in text:
            return text
        if "frontend-app-discussions.git#open-release/redwood.3" not in text and \
           "discussions-src" in text:
            return text
        return text

    # Ensure MFEs build against Node 24 with the required toolchain.
    updated = re.sub(
        r"^FROM\s+(?:docker[.]io/)?node:[^ \t\r\n]+",
        "FROM docker.io/node:24.11.0-bullseye-slim",
        updated,
        flags=re.MULTILINE,
    )
    # Fix toolchain packages for Debian bullseye-slim:
    #  - "python" doesn't exist on Debian 11+; replace with "python3"
    #  - Ensure python3-distutils is present for node-gyp
    # Match both old format ("gcc git libgl1 ...") and new ("gcc libgl1 ...").
    if "gcc git libgl1 libxi6 make" in updated:
        updated = updated.replace(
            "gcc git libgl1 libxi6 make",
            "gcc g++ git libgl1 libxi6 make python3 python3-distutils",
        )
    # Tutor v21 (Ulmo) puts "python g++" on a separate line for arm deps.
    # Replace "python" with "python3" and add python3-distutils.
    updated = re.sub(
        r"(\s+)python g\+\+",
        r"\1python3 g++ python3-distutils",
        updated,
    )

    # ── Network resilience for ARC DinD runners ────────────────────────
    # ARC container runners have flaky outbound networking (connection
    # timeouts to Debian mirrors).  Inject apt retry config before the
    # first `apt update` so transient failures don't kill the build.
    if "apt update" in updated and "Acquire::Retries" not in updated:
        updated = re.sub(
            r"(RUN\s+)apt update",
            r'\1echo \'Acquire::Retries "5";\' > /etc/apt/apt.conf.d/80-retries && \\\n    apt-get update -o Acquire::CompressionTypes::Order::=gz',
            updated,
            count=1,
        )
        # Also replace plain 'apt install' with 'apt-get install' for
        # better scripting behaviour + add --fix-broken.
        updated = updated.replace(
            "&& apt install -y",
            "&& apt-get install -y --fix-broken",
        )

    updated = ensure_mfe_ulmo_source_refs(updated)
    updated = ensure_mfe_brand_ulmo_version(updated)
    updated = ensure_mfe_discussions_webpack_noninteractive(updated)
    updated = ensure_mfe_cookie_env(updated)
    updated = ensure_mfe_theme_copy(updated)
    updated = ensure_mfe_npm_resilience(updated)
    updated = ensure_mfe_plugin_framework_dependency(updated)
    updated = ensure_mfe_admin_console_redux_deps(updated)
    updated = ensure_mfe_course_authoring_directory_fix(updated)
    updated = ensure_mfe_new_relic_env(updated)

    if updated != original:
        path.write_text(updated)
PY
}
