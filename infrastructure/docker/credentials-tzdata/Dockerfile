# Dockerfile
# Derivative credentials image with tzdata for production deployments.
#
# The upstream docker.io/overhangio/openedx-credentials image does not include
# the tzdata Python package, which is required for ZoneInfo("UTC") to function
# correctly on the container OS (Debian-based images lack system tzdata files).
#
# The Tutor plugin (mereka_lms.py credentials-dockerfile-post-python-requirements)
# installs tzdata during local image builds, but production uses the pre-built
# upstream image and therefore needs this derivative wrapper.
#
# Build (see scripts/infra/build-credentials-image.sh for wrapper):
#   docker build -f infrastructure/docker/credentials-tzdata/Dockerfile \
#     -t asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-credentials:21.0.0-tzdata \
#     infrastructure/docker/credentials-tzdata

ARG UPSTREAM_IMAGE=docker.io/overhangio/openedx-credentials
ARG UPSTREAM_TAG=21.0.0
FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG}

# Install tzdata so ZoneInfo("UTC") works without OS-level tzdata files.
# Also install cryptography for Ed25519 key operations (matches Tutor plugin).
RUN pip install --no-cache-dir "tzdata>=2024.1" "cryptography>=41.0.0"
