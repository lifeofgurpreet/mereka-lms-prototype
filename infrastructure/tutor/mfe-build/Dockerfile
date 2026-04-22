# syntax=mirror.gcr.io/docker/dockerfile:1
# https://hub.docker.com/_/node/tags
FROM mirror.gcr.io/library/node:24.11.0-bullseye-slim AS base

RUN printf '%s\n' \
    'Acquire::Retries "6";' \
    'Acquire::http::Timeout "30";' \
    'Acquire::https::Timeout "30";' \
    'Acquire::ForceIPv4 "true";' \
    > /etc/apt/apt.conf.d/80-retries && \
    apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing git \
    # required for cwebp-bin
    gcc libgl1 libxi6 make \
    # required for gifsicle, mozjpeg, and optipng (on arm)
    autoconf libtool pkg-config zlib1g-dev \
    # required for node-sass (on arm)
    python3 g++ python3-distutils \
    # required for image-webpack-loader (on arm)
    libpng-dev \
    # required for building node-canvas (on arm, for authoring)
    # https://www.npmjs.com/package/canvas
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /openedx/app /openedx/env
WORKDIR /openedx/app
ENV PATH=/openedx/app/node_modules/.bin:${PATH}




####################### admin-console MFE
######## admin-console (git)
FROM base AS admin-console-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-admin-console.git#release/ulmo.2 .

######## admin-console (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS admin-console-src
COPY --from=admin-console-git /openedx/app /

######## admin-console (common)
FROM base AS admin-console-common
COPY --from=admin-console-src /package.json /openedx/app/package.json
COPY --from=admin-console-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1'
COPY --from=admin-console-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 2025

# Configuration needed at build time
ENV APP_ID=admin-console
ENV PUBLIC_PATH='/admin-console/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## admin-console (dev)
FROM admin-console-common AS admin-console-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### authn MFE
######## authn (git)
FROM base AS authn-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-authn.git#release/ulmo.2 .

######## authn (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS authn-src
COPY --from=authn-git /openedx/app /

######## authn (common)
FROM base AS authn-common
COPY --from=authn-src /package.json /openedx/app/package.json
COPY --from=authn-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1'

COPY patch-authn-deep-route-handoff.py /openedx/patch-authn-deep-route-handoff.py
COPY patch-authn-dashboard-fallbacks.py /openedx/patch-authn-dashboard-fallbacks.py
COPY verify-authn-dashboard-fallbacks.py /openedx/verify-authn-dashboard-fallbacks.py
COPY --from=authn-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1999

# Configuration needed at build time
ENV APP_ID=authn
ENV PUBLIC_PATH='/authn/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app


RUN python3 /openedx/patch-authn-dashboard-fallbacks.py /openedx/app

######## authn (dev)
FROM authn-common AS authn-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### authoring MFE
######## authoring (git)
FROM base AS authoring-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-authoring.git#release/ulmo.2 .

######## authoring (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS authoring-src
COPY --from=authoring-git /openedx/app /

######## authoring (common)
FROM base AS authoring-common
COPY --from=authoring-src /package.json /openedx/app/package.json
COPY --from=authoring-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=authoring-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 2001

# Configuration needed at build time
ENV APP_ID=authoring
ENV PUBLIC_PATH='/authoring/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## authoring (dev)
FROM authoring-common AS authoring-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### account MFE
######## account (git)
FROM base AS account-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-account.git#release/ulmo.2 .

######## account (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS account-src
COPY --from=account-git /openedx/app /

######## account (common)
FROM base AS account-common
COPY --from=account-src /package.json /openedx/app/package.json
COPY --from=account-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=account-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1997

# Configuration needed at build time
ENV APP_ID=account
ENV PUBLIC_PATH='/account/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app


RUN python3 - <<'PY'
from pathlib import Path

service_path = Path("/openedx/app/src/account-settings/data/service.js")
if not service_path.exists():
    raise SystemExit(0)

original = "const platformData = data.social_links.find(({ platform }) => platform === id);"
patched = (
    "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];\n"
    "      const platformData = socialLinks.find(({ platform }) => platform === id);"
)

content = service_path.read_text(encoding="utf-8")
if patched in content:
    raise SystemExit(0)  # already patched — idempotent
if original not in content:
    raise SystemExit("account social_links patch anchor missing — upstream may have changed")

updated = content.replace(original, patched)
service_path.write_text(updated, encoding="utf-8")
print("account social_links null-safety patch applied")
PY

######## account (dev)
FROM account-common AS account-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### communications MFE
######## communications (git)
FROM base AS communications-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-communications.git#release/ulmo.2 .

######## communications (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS communications-src
COPY --from=communications-git /openedx/app /

######## communications (common)
FROM base AS communications-common
COPY --from=communications-src /package.json /openedx/app/package.json
COPY --from=communications-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=communications-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1984

# Configuration needed at build time
ENV APP_ID=communications
ENV PUBLIC_PATH='/communications/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## communications (dev)
FROM communications-common AS communications-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### discussions MFE
######## discussions (git)
FROM base AS discussions-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-discussions.git#release/ulmo.2 .

######## discussions (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS discussions-src
COPY --from=discussions-git /openedx/app /

######## discussions (common)
FROM base AS discussions-common
COPY --from=discussions-src /package.json /openedx/app/package.json
COPY --from=discussions-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=discussions-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 2002

# Configuration needed at build time
ENV APP_ID=discussions
ENV PUBLIC_PATH='/discussions/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## discussions (dev)
FROM discussions-common AS discussions-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### gradebook MFE
######## gradebook (git)
FROM base AS gradebook-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-gradebook.git#release/ulmo.2 .

######## gradebook (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS gradebook-src
COPY --from=gradebook-git /openedx/app /

######## gradebook (common)
FROM base AS gradebook-common
COPY --from=gradebook-src /package.json /openedx/app/package.json
COPY --from=gradebook-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=gradebook-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1994

# Configuration needed at build time
ENV APP_ID=gradebook
ENV PUBLIC_PATH='/gradebook/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## gradebook (dev)
FROM gradebook-common AS gradebook-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### learner-dashboard MFE
######## learner-dashboard (git)
FROM base AS learner-dashboard-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-learner-dashboard.git#release/ulmo.2 .

######## learner-dashboard (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS learner-dashboard-src
COPY --from=learner-dashboard-git /openedx/app /

######## learner-dashboard (common)
FROM base AS learner-dashboard-common
COPY --from=learner-dashboard-src /package.json /openedx/app/package.json
COPY --from=learner-dashboard-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=learner-dashboard-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1996

# Configuration needed at build time
ENV APP_ID=learner-dashboard
ENV PUBLIC_PATH='/learner-dashboard/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## learner-dashboard (dev)
FROM learner-dashboard-common AS learner-dashboard-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### learning MFE
######## learning (git)
FROM base AS learning-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-learning.git#release/ulmo.2 .

######## learning (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS learning-src
COPY --from=learning-git /openedx/app /

######## learning (common)
FROM base AS learning-common
COPY --from=learning-src /package.json /openedx/app/package.json
COPY --from=learning-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=learning-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 2000

# Configuration needed at build time
ENV APP_ID=learning
ENV PUBLIC_PATH='/learning/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## learning (dev)
FROM learning-common AS learning-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### ora-grading MFE
######## ora-grading (git)
FROM base AS ora-grading-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-ora-grading.git#release/ulmo.2 .

######## ora-grading (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS ora-grading-src
COPY --from=ora-grading-git /openedx/app /

######## ora-grading (common)
FROM base AS ora-grading-common
COPY --from=ora-grading-src /package.json /openedx/app/package.json
COPY --from=ora-grading-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=ora-grading-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1993

# Configuration needed at build time
ENV APP_ID=ora-grading
ENV PUBLIC_PATH='/ora-grading/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## ora-grading (dev)
FROM ora-grading-common AS ora-grading-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### profile MFE
######## profile (git)
FROM base AS profile-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-profile.git#release/ulmo.2 .

######## profile (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS profile-src
COPY --from=profile-git /openedx/app /

######## profile (common)
FROM base AS profile-common
COPY --from=profile-src /package.json /openedx/app/package.json
COPY --from=profile-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=profile-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1995

# Configuration needed at build time
ENV APP_ID=profile
ENV PUBLIC_PATH='/profile/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## profile (dev)
FROM profile-common AS profile-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### learner-record MFE
######## learner-record (git)
FROM base AS learner-record-git
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-learner-record.git#release/ulmo.2 .

######## learner-record (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS learner-record-src
COPY --from=learner-record-git /openedx/app /

######## learner-record (common)
FROM base AS learner-record-common
COPY --from=learner-record-src /package.json /openedx/app/package.json
COPY --from=learner-record-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/

# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \
    ca-certificates gcc g++ git libgl1 libxi6 make python3 python3-distutils \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This protects any git-based npm dependency resolution in upstream MFE sources.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
# mfe-npm-install-resilience-sentinel - apply-patches.sh
RUN --mount=type=cache,target=/root/.npm,sharing=shared bash -o pipefail -c 'npm config set fetch-retries 6; npm config set fetch-retry-mintimeout 20000; npm config set fetch-retry-maxtimeout 120000; npm config set fetch-timeout 300000; for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install fallback attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'

COPY mereka/brand-mereka /openedx/app/brand-mereka
RUN python3 - <<'PY'
from pathlib import Path
import json
import shutil

src = Path("/openedx/app/brand-mereka")
dest = Path("/openedx/app/node_modules/@edx/brand")

if not (src / "package.json").is_file():
    raise SystemExit(f"brand package source is missing package.json: {src}")

if dest.exists() or dest.is_symlink():
    if dest.is_dir() and not dest.is_symlink():
        shutil.rmtree(dest)
    else:
        dest.unlink()

dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(src, dest)

package_json = dest / "package.json"
payload = json.loads(package_json.read_text(encoding="utf-8"))
payload["name"] = "@edx/brand"
payload.pop("devDependencies", None)
package_json.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")

print(f"materialized local brand package at {dest}")
PY

COPY mereka/theme-source /openedx/app/theme-source

COPY mereka/theme /openedx/dist/theme

# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'

# Sentry Browser SDK — client-side error telemetry (OBS-001, bead mereka-lms-m88z).
# Init gated on getConfig().SENTRY_DSN at runtime; empty DSN → no-op.
RUN npm install --legacy-peer-deps '@sentry/browser@^8.0.0'

# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx'     -exec sed -i 's/const endDateObj = moment\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} +     || true

COPY --from=learner-record-src / /openedx/app

# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry
RUN bash -o pipefail -c 'for attempt in 1 2 3; do make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=release/ulmo " pull_translations && exit 0; echo "pull_translations attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
EXPOSE 1990

# Configuration needed at build time
ENV APP_ID=learner-record
ENV PUBLIC_PATH='/learner-record/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
COPY env.config.jsx /openedx/app



######## learner-record (dev)
FROM learner-record-common AS learner-record-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]


# Production images are last to accelerate dev image building
######## admin-console (production)
FROM admin-console-common AS admin-console-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## authn (production)
FROM authn-common AS authn-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY

RUN python3 /openedx/patch-authn-deep-route-handoff.py /openedx/app/dist \
 && python3 /openedx/verify-authn-dashboard-fallbacks.py /openedx/app/dist

######## authoring (production)
FROM authoring-common AS authoring-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## account (production)
FROM account-common AS account-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## communications (production)
FROM communications-common AS communications-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## discussions (production)
FROM discussions-common AS discussions-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## gradebook (production)
FROM gradebook-common AS gradebook-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## learner-dashboard (production)
FROM learner-dashboard-common AS learner-dashboard-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## learning (production)
FROM learning-common AS learning-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## ora-grading (production)
FROM ora-grading-common AS ora-grading-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## profile (production)
FROM profile-common AS profile-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY


######## learner-record (production)
FROM learner-record-common AS learner-record-prod
ENV NODE_ENV=production
RUN npm run build

RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix != ".js":
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY

RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")

paragon_theme_expr = None
replacement_start = None
replacement_end = None

object_match = re.search(r"var PARAGON_THEME = (\{.*?\});", content, re.DOTALL)
if object_match:
    paragon_theme_expr = object_match.group(1)
    replacement_start = object_match.start(1)
    replacement_end = object_match.end(1)
else:
    iife_match = re.search(
        r"var PARAGON_THEME = (?P<expr>\(\(\) => \{.*?\}\)\(\));",
        content,
        re.DOTALL,
    )
    if iife_match:
        theme_object_match = re.search(
            r"const theme = (\{.*?\});",
            iife_match.group("expr"),
            re.DOTALL,
        )
        if theme_object_match:
            paragon_theme_expr = theme_object_match.group(1)
            replacement_start = iife_match.start("expr")
            replacement_end = iife_match.end("expr")

if paragon_theme_expr is None:
    raise SystemExit(0)

theme = json.loads(paragon_theme_expr)

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "/theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "/theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "/theme/biji-biji-brand.min.css",
        "light": "/theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "/theme/sof-brand.min.css",
        "light": "/theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\.)?apps\./, ""));
      enqueue(candidate.replace(/^apps\./, ""));
      enqueue(candidate.replace(/^staging\./, ""));
      enqueue(candidate.replace(/\.mereka\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:replacement_start] + runtime_theme + content[replacement_end:]
index_path.write_text(updated, encoding="utf-8")
PY



####### final production image with all static assets
FROM mirror.gcr.io/library/caddy:2.7.4 AS production

RUN mkdir -p /openedx/dist

# Copy static assets

COPY --from=admin-console-prod /openedx/app/dist /openedx/dist/admin-console

COPY --from=authn-prod /openedx/app/dist /openedx/dist/authn

COPY --from=authoring-prod /openedx/app/dist /openedx/dist/authoring

COPY --from=account-prod /openedx/app/dist /openedx/dist/account

COPY --from=communications-prod /openedx/app/dist /openedx/dist/communications

COPY --from=discussions-prod /openedx/app/dist /openedx/dist/discussions

COPY --from=gradebook-prod /openedx/app/dist /openedx/dist/gradebook

COPY --from=learner-dashboard-prod /openedx/app/dist /openedx/dist/learner-dashboard

COPY --from=learning-prod /openedx/app/dist /openedx/dist/learning

COPY --from=ora-grading-prod /openedx/app/dist /openedx/dist/ora-grading

COPY --from=profile-prod /openedx/app/dist /openedx/dist/profile

COPY --from=learner-record-prod /openedx/app/dist /openedx/dist/learner-record



COPY mereka/theme /openedx/dist/theme