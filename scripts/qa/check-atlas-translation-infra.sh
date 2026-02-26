#!/usr/bin/env bash
# Verify atlas.yml is present and references all required locales.
# Also verifies TRANSLATION_WORKFLOW.md and sync-translations.sh exist.
set -euo pipefail

[[ -f atlas.yml ]] || { echo "FAIL: atlas.yml missing from repo root"; exit 1; }
echo "PASS: atlas.yml present"

[[ -f docs/operations/TRANSLATION_WORKFLOW.md ]] || { echo "FAIL: TRANSLATION_WORKFLOW.md missing"; exit 1; }
echo "PASS: TRANSLATION_WORKFLOW.md present"

[[ -x scripts/infra/sync-translations.sh ]] || { echo "FAIL: sync-translations.sh missing or not executable"; exit 1; }
echo "PASS: sync-translations.sh is executable"

for locale in en id zh_CN vi fil; do
  grep -q "$locale" atlas.yml || { echo "FAIL: atlas.yml missing locale: $locale"; exit 1; }
  echo "PASS: atlas.yml references locale: $locale"
done
