#!/bin/sh
# strip-nreum.sh
# Remove NREUM <script> blocks from an HTML file and ensure env.config.js
# is loaded for runtime config.
# Usage: strip-nreum.sh /path/to/index.html
#
# Handles minified/inline scripts where multiple <script> tags can appear on a
# single line and avoids line-by-line parser blind spots.

set -eu

HTML_FILE="${1:-/openedx/dist/index.html}"
TMP_FILE="$(mktemp)"

if [ ! -f "$HTML_FILE" ]; then
  echo "[strip-nreum] File not found: $HTML_FILE — skip"
  rm -f "$TMP_FILE"
  exit 0
fi

awk '
{
  html = html $0 "\n"
}
END {
  out = ""
  rest = html
  while (1) {
    start = match(rest, /<script[^>]*>/)
    if (start == 0) {
      out = out rest
      break
    }

    out = out substr(rest, 1, start - 1)
    rest = substr(rest, start)

    start_tag_len = RLENGTH
    start_tag = substr(rest, 1, start_tag_len)
    body_rest = substr(rest, start_tag_len + 1)

    close_offset = index(body_rest, "</script>")
    if (close_offset == 0) {
      out = out rest
      break
    }

    script_block = start_tag substr(body_rest, 1, close_offset - 1) "</script>"
    rest = substr(body_rest, close_offset + 9)

    if (index(script_block, "NREUM") == 0) {
      out = out script_block
    }
  }
  printf "%s", out
}' "$HTML_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$HTML_FILE"

# Verify
if [ ! -s "$HTML_FILE" ]; then
  echo "[strip-nreum] ERROR: stripped file is empty"
  exit 1
fi

if ! grep -qE '<!DOCTYPE html>|<html' "$HTML_FILE" 2>/dev/null; then
  echo "[strip-nreum] ERROR: stripped file does not look like HTML"
  exit 1
fi

if grep -q 'undefined_license_key' "$HTML_FILE" 2>/dev/null; then
  echo "[strip-nreum] ERROR: undefined_license_key still present after strip"
  exit 1
fi

# Ensure runtime config is loaded by enterprise MFEs.
if ! grep -q 'src="/env.config.js"' "$HTML_FILE" 2>/dev/null; then
  TMP_INJECT="$(mktemp)"
  awk '
  BEGIN { added = 0 }
  {
    line = $0
    if (!added && index(line, "</head>") > 0) {
      sub("</head>", "<script src=\"/env.config.js\"></script></head>", line)
      added = 1
    }
    print line
  }
  END {
    if (!added) exit 42
  }' "$HTML_FILE" > "$TMP_INJECT" || {
    code=$?
    rm -f "$TMP_INJECT"
    if [ "$code" -eq 42 ]; then
      echo "[strip-nreum] ERROR: could not inject env.config.js (missing </head>)"
    fi
    exit 1
  }
  mv "$TMP_INJECT" "$HTML_FILE"
fi

if ! grep -q 'src="/env.config.js"' "$HTML_FILE" 2>/dev/null; then
  echo "[strip-nreum] ERROR: env.config.js script is still missing"
  exit 1
fi

echo "[strip-nreum] OK: $(wc -c < "$HTML_FILE") bytes, no undefined_license_key, env.config.js wired"
