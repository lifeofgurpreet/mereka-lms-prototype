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

  # Use Python for reliable multi-line Dockerfile patching.
  # sed multi-line inserts are fragile — the previous version inserted
  # inside the base stage instead of before the learner-record section,
  # breaking ALL MFE builds.
  python3 - "$mfe_dockerfile" <<'PYEOF'
import sys
from pathlib import Path

dockerfile = Path(sys.argv[1])
content = dockerfile.read_text()

# The Node 18 base stage to insert
node18_stage = """
# learner-record requires Node 18 (webpack 4 incompatible with Node 24)
FROM docker.io/node:18-bullseye-slim AS learner-record-node18-base
RUN apt-get update && apt-get install -y git gcc g++ make python3 libgl1 libxi6 \
    libpng-dev autoconf libtool pkg-config zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /openedx/app /openedx/env
WORKDIR /openedx/app
ENV PATH=/openedx/app/node_modules/.bin:${PATH}

"""

# Insert BEFORE the learner-record-git stage (not after the base stage!)
marker = "FROM base AS learner-record-git"
if marker not in content:
    print("    SKIP: learner-record-git stage not found (MFE may not be registered yet)")
    sys.exit(0)

content = content.replace(marker, node18_stage + "FROM learner-record-node18-base AS learner-record-git")

# Also rebase learner-record-common on the Node 18 base
content = content.replace(
    "FROM base AS learner-record-common",
    "FROM learner-record-node18-base AS learner-record-common"
)

dockerfile.write_text(content)
print("    OK: learner-record pinned to Node 18")
PYEOF
}
