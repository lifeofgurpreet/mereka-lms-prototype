#!/usr/bin/env bash
# Regenerate verification catalog artifacts and stage them for the current commit.
#
# Invoked by the pre-commit hook "verification-catalog-regen" whenever files that
# feed the generator change (verify-*.sh scripts, CI inventory files, workflow
# references, status overrides, or deprecation manifests).
#
# Pattern: generate → git add → exit 0  (catalog is included in the commit transparently).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 "${REPO_ROOT}/scripts/qa/generate-verification-catalog.py"

git -C "${REPO_ROOT}" add \
  verification/catalogs/verification_catalog.json \
  verification/catalogs/VERIFICATION_CATALOG.md
