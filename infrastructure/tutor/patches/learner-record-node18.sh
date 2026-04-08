#!/usr/bin/env bash
# Patch: Pin Node 18 for learner-record MFE stages.
#
# learner-record uses webpack 4, which is incompatible with Node 24
# (OpenSSL 3.x, removed punycode, deprecated hash functions).
# This patch modifies the Tutor-generated MFE Dockerfile to use
# a Node 18 base image for the learner-record-common stage only.
#
# Idempotent: safe to run multiple times.

apply_learner_record_node18_patch() {
  local mfe_dockerfile
  mfe_dockerfile="${TUTOR_ROOT:-$(pwd)/tutor_env}/env/plugins/mfe/build/mfe/Dockerfile"

  if [[ ! -f "$mfe_dockerfile" ]]; then
    echo "    SKIP: MFE Dockerfile not found at $mfe_dockerfile"
    return 0
  fi

  # Check if patch already applied
  if grep -q "learner-record-node18-base" "$mfe_dockerfile" 2>/dev/null; then
    echo "    SKIP: learner-record Node 18 patch already applied"
    return 0
  fi

  # 1. Add Node 18 base image stage near the top (after the first FROM line)
  # Insert after the first FROM line that defines 'base'
  sed -i '/^FROM.*AS base$/a\
\
# learner-record requires Node 18 (webpack 4 incompatible with Node 24)\
FROM docker.io/node:18-bullseye-slim AS learner-record-node18-base\
RUN apt-get update \&\& apt-get install -y git gcc g++ make python3 libgl1 libxi6 \\\
    libpng-dev autoconf libtool pkg-config zlib1g-dev \\\
    \&\& rm -rf /var/lib/apt/lists/*\
RUN mkdir -p /openedx/app /openedx/env\
WORKDIR /openedx/app\
ENV PATH=/openedx/app/node_modules/.bin:${PATH}' "$mfe_dockerfile"

  # 2. Change learner-record-common to inherit from learner-record-node18-base instead of base
  sed -i 's/^FROM base AS learner-record-common$/FROM learner-record-node18-base AS learner-record-common/' "$mfe_dockerfile"

  # 3. Change learner-record-git to inherit from learner-record-node18-base instead of base
  sed -i 's/^FROM base AS learner-record-git$/FROM learner-record-node18-base AS learner-record-git/' "$mfe_dockerfile"

  # Verify patch was applied
  if grep -q "learner-record-node18-base" "$mfe_dockerfile"; then
    echo "    OK: learner-record pinned to Node 18"
  else
    echo "    WARN: learner-record Node 18 patch may not have applied correctly"
    return 1
  fi
}
