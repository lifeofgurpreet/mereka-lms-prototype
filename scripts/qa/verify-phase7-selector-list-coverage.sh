#!/usr/bin/env bash
# Verify phase7_full selector list covers all .mereka-* classes in mereka.scss.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCSS_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
SELECTOR_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-full-selectors.txt"

echo "Checking Phase 7 selector-list coverage..."

if [[ ! -f "$SCSS_FILE" ]]; then
  echo "❌ Missing SCSS source: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
  exit 1
fi

if [[ ! -f "$SELECTOR_FILE" ]]; then
  echo "❌ Missing selector list: scripts/qa/mfe-live-dom-phase7-full-selectors.txt"
  exit 1
fi

expected_tmp="$(mktemp)"
listed_tmp="$(mktemp)"
missing_tmp="$(mktemp)"
trap 'rm -f "$expected_tmp" "$listed_tmp" "$missing_tmp"' EXIT

# Strip comment-only lines, then extract class selectors touched by phase7 branding.
grep -vE '^\s*(/\*|\*|//)' "$SCSS_FILE" \
  | rg -o '\.mereka-[A-Za-z0-9_-]+' \
  | sort -u > "$expected_tmp"

grep -Ev '^\s*($|#)' "$SELECTOR_FILE" \
  | sed 's/^\s*//' \
  | cut -d' ' -f1 \
  | sort -u > "$listed_tmp"

expected_count="$(wc -l < "$expected_tmp" | tr -d ' ')"

if [[ "$expected_count" -lt 20 ]]; then
  echo "❌ Unexpectedly low .mereka-* selector count in SCSS ($expected_count, expected >=20)"
  exit 1
fi

comm -23 "$expected_tmp" "$listed_tmp" > "$missing_tmp"
missing_count="$(wc -l < "$missing_tmp" | tr -d ' ')"

if [[ "$missing_count" -ne 0 ]]; then
  echo "❌ Phase 7 full selector list is missing $missing_count .mereka-* selectors:"
  sed 's/^/  - /' "$missing_tmp"
  exit 1
fi

echo "✅ Phase 7 selector-list coverage passed ($expected_count .mereka-* selectors covered)."
