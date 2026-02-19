#!/bin/sh
# strip-nreum.sh
# Remove NREUM <script> blocks from an HTML file.
# Usage: strip-nreum.sh /path/to/index.html
#
# Handles multi-line <script> blocks containing NREUM.
# Used as a COPY+RUN step in enterprise MFE Dockerfiles to strip at build time.

set -eu

HTML_FILE="${1:-/openedx/dist/index.html}"

if [ ! -f "$HTML_FILE" ]; then
  echo "[strip-nreum] File not found: $HTML_FILE — skip"
  exit 0
fi

awk '
  BEGIN {in_script=0; buf=""; has_nreum=0}
  {
    if (in_script) {
      buf = buf $0 "\n"
      if ($0 ~ /NREUM/) { has_nreum = 1 }
      if ($0 ~ /<\/script>/) {
        if (!has_nreum) { printf "%s", buf }
        in_script = 0; buf = ""; has_nreum = 0
      }
      next
    }
    if ($0 ~ /<script/) {
      in_script = 1
      has_nreum = ($0 ~ /NREUM/) ? 1 : 0
      buf = $0 "\n"
      if ($0 ~ /<\/script>/) {
        if (!has_nreum) { printf "%s", buf }
        in_script = 0; buf = ""; has_nreum = 0
      }
      next
    }
    print
  }
  END { if (in_script && !has_nreum) { printf "%s", buf } }
' "$HTML_FILE" > /tmp/index-nreum-clean.html

mv /tmp/index-nreum-clean.html "$HTML_FILE"

# Verify
if grep -q 'undefined_license_key' "$HTML_FILE" 2>/dev/null; then
  echo "[strip-nreum] ERROR: undefined_license_key still present after strip"
  exit 1
fi

echo "[strip-nreum] OK: $(wc -c < "$HTML_FILE") bytes, no undefined_license_key"
