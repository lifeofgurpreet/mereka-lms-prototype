#!/usr/bin/env bash
# Verify that the canonical MFE selector inventory covers every .mereka-* class
# emitted by the MFE manifest and split partials.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_SCSS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe"
SELECTOR_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-full-selectors.txt"

echo "Checking MFE selector coverage..."

if [[ ! -f "$MFE_SCSS_DIR/mereka.scss" ]]; then
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

{
  cat "$MFE_SCSS_DIR/mereka.scss"
  if [[ -d "$MFE_SCSS_DIR/scss" ]]; then
    cat "$MFE_SCSS_DIR"/scss/*.scss
  fi
} | grep -vE '^\s*(/\*|\*|//)' \
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
  echo "❌ Canonical selector inventory is missing $missing_count .mereka-* selectors:"
  sed 's/^/  - /' "$missing_tmp"
  exit 1
fi

echo "✅ MFE selector coverage passed ($expected_count .mereka-* selectors covered)."
