#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_runtime"
RUNTIME_FILE="$RUNTIME_DIR/tenant-resolution-runtime.js"

surface_files=(
  "$RUNTIME_DIR/header-menu.js"
  "$RUNTIME_DIR/dashboard.js"
  "$RUNTIME_DIR/learning.js"
  "$RUNTIME_DIR/certificate-profile.js"
  "$RUNTIME_DIR/authoring.js"
  "$RUNTIME_DIR/footer.js"
)

if [[ ! -f "$RUNTIME_FILE" ]]; then
  echo "FAIL: missing runtime helper source: ${RUNTIME_FILE#"$REPO_ROOT"/}"
  exit 1
fi

failures=0
tmp_calls="$(mktemp)"
trap 'rm -f "$tmp_calls"' EXIT

grep -RhoE '\b(getMereka[A-Za-z0-9_]+|getLearnerHomeHref|getCatalogHref|getLogoHref)\b' "${surface_files[@]}" \
  | sort -u \
  | grep -v '^getMerekaFooterNavLinks$' \
  > "$tmp_calls"

echo "=== MFE Runtime Helper Contract ==="
echo "Runtime: ${RUNTIME_FILE#"$REPO_ROOT"/}"

while IFS= read -r helper; do
  [[ -n "$helper" ]] || continue

  if grep -Eq "(const|function)[[:space:]]+$helper\\b" "$RUNTIME_FILE"; then
    echo "PASS: $helper provided by tenant-resolution-runtime.js"
  else
    echo "FAIL: $helper is used by a surface module but missing from tenant-resolution-runtime.js"
    failures=$((failures + 1))
  fi
done < "$tmp_calls"

if [[ "$failures" -gt 0 ]]; then
  echo "RESULT: FAIL ($failures missing helper(s))"
  exit 1
fi

echo "RESULT: PASS"
