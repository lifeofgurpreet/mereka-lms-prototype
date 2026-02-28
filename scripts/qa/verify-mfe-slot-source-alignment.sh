#!/usr/bin/env bash
# Verify plugin slot IDs stay aligned with locally checked-out Ulmo MFE source trees.
# This catches regressions where slot IDs are wired in plugin config but do not exist
# in the source for MFEs available under tutor_env/dev/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
STRICT="${STRICT:-1}"
STRICT_LOCAL_LEARNING_COMPLETE="${STRICT_LOCAL_LEARNING_COMPLETE:-1}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }

if [[ ! -f "$PLUGIN_FILE" ]]; then
  echo "FAIL: plugin file missing: ${PLUGIN_FILE#$REPO_ROOT/}"
  exit 1
fi

AUTHN_SRC="$REPO_ROOT/tutor_env/dev/frontend-app-authn/src"
ACCOUNT_SRC="$REPO_ROOT/tutor_env/dev/frontend-app-account/src"
PROFILE_SRC="$REPO_ROOT/tutor_env/dev/frontend-app-profile/src"
LEARNING_SRC="$REPO_ROOT/tutor_env/dev/frontend-app-learning/src"
AUTHORING_SRC="$REPO_ROOT/tutor_env/dev/frontend-app-course-authoring/src"

echo "=== MFE Slot Source Alignment Verification ==="

slots="$(
  python3 - "$PLUGIN_FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
slot_ids = sorted(set(re.findall(r"org\.openedx\.frontend\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\.v[0-9]+", text)))
for slot in slot_ids:
    print(slot)
PY
)"

if [[ -z "$slots" ]]; then
  fail "No namespaced slot IDs found in plugin"
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

pass "Found $(echo "$slots" | wc -l | tr -d ' ') namespaced slot IDs in plugin"

check_slot_in_source() {
  local slot="$1"
  local source_dir="$2"
  local label="$3"

  if [[ ! -d "$source_dir" ]]; then
    warn "Source checkout missing for ${label}: ${source_dir#$REPO_ROOT/}"
    return
  fi

  if rg -qF "$slot" "$source_dir"; then
    pass "Slot exists in ${label} source: $slot"
  else
    if [[ "$STRICT" == "1" ]]; then
      fail "Slot missing in ${label} source: $slot"
    else
      warn "Slot missing in ${label} source (STRICT=0): $slot"
    fi
  fi
}

while IFS= read -r slot; do
  [[ -z "$slot" ]] && continue

  case "$slot" in
    org.openedx.frontend.authn.*)
      check_slot_in_source "$slot" "$AUTHN_SRC" "authn"
      ;;
    org.openedx.frontend.account.*)
      check_slot_in_source "$slot" "$ACCOUNT_SRC" "account"
      ;;
    org.openedx.frontend.profile.*)
      check_slot_in_source "$slot" "$PROFILE_SRC" "profile"
      ;;
    org.openedx.frontend.learning.*|org.openedx.frontend.layout.header_learning.v1)
      check_slot_in_source "$slot" "$LEARNING_SRC" "learning"
      ;;
    org.openedx.frontend.authoring.*)
      check_slot_in_source "$slot" "$AUTHORING_SRC" "authoring"
      ;;
    *)
      warn "No local source-alignment check for slot (external/checkout not present): $slot"
      ;;
  esac
done <<<"$slots"

if [[ -d "$LEARNING_SRC" ]]; then
  learning_missing="$(
    SLOT_LINES="$slots" python3 - "$LEARNING_SRC" <<'PY'
import re
import os
import sys
from pathlib import Path

learning_src = Path(sys.argv[1])
slot_pattern = re.compile(r"org\.openedx\.frontend\.learning\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*\.v[0-9]+")

source_slots = set()
for path in learning_src.rglob("*"):
    if path.suffix.lower() not in {".js", ".jsx", ".ts", ".tsx", ".md"}:
        continue
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue
    source_slots.update(slot_pattern.findall(text))

plugin_slots = set()
for line in os.environ.get("SLOT_LINES", "").splitlines():
    line = line.strip()
    if line.startswith("org.openedx.frontend.learning."):
        plugin_slots.add(line)

for slot in sorted(source_slots - plugin_slots):
    print(slot)
PY
  )"

  if [[ -z "$learning_missing" ]]; then
    pass "Learning plugin coverage is complete for local source checkout (all discovered learning slot IDs are wired)"
  else
    missing_count="$(echo "$learning_missing" | wc -l | tr -d ' ')"
    if [[ "$STRICT_LOCAL_LEARNING_COMPLETE" == "1" ]]; then
      fail "Learning plugin coverage gap: $missing_count local learning slot ID(s) are not wired"
      while IFS= read -r slot; do
        [[ -n "$slot" ]] && fail "Unwired local learning slot: $slot"
      done <<<"$learning_missing"
    else
      warn "Learning plugin coverage gap (STRICT_LOCAL_LEARNING_COMPLETE=0): $missing_count local learning slot ID(s) are not wired"
      while IFS= read -r slot; do
        [[ -n "$slot" ]] && warn "Unwired local learning slot: $slot"
      done <<<"$learning_missing"
    fi
  fi
else
  warn "Learning source checkout missing; cannot evaluate local learning slot completeness"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
