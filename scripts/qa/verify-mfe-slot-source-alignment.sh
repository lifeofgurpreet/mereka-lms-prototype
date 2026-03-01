#!/usr/bin/env bash
# Verify plugin slot IDs stay aligned with Ulmo MFE source trees.
# By default, this checks local tutor_env/dev checkouts first and optionally falls
# back to an external source root (for example /tmp/mfe-slot-inspect).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
STRICT="${STRICT:-1}"
STRICT_LOCAL_LEARNING_COMPLETE="${STRICT_LOCAL_LEARNING_COMPLETE:-1}"
CHECK_LAYOUT_SLOT_EXISTENCE="${CHECK_LAYOUT_SLOT_EXISTENCE:-0}"
ULMO_SLOT_SOURCE_FALLBACK="${ULMO_SLOT_SOURCE_FALLBACK:-/tmp/mfe-slot-inspect}"

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

pick_source_dir() {
  local candidate
  for candidate in "$@"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  echo ""
}

AUTHN_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-authn/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-authn/src")"
ACCOUNT_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-account/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-account/src")"
PROFILE_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-profile/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-profile/src")"
LEARNING_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-learning/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-learning/src")"
AUTHORING_SRC=""
for candidate in \
  "$REPO_ROOT/tutor_env/dev/frontend-app-authoring/src" \
  "$REPO_ROOT/tutor_env/dev/frontend-app-course-authoring/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-authoring/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-course-authoring/src"
do
  if [[ -d "$candidate" ]]; then
    AUTHORING_SRC="$candidate"
    break
  fi
done
GRADEBOOK_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-gradebook/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-gradebook/src")"
DASHBOARD_SRC="$(pick_source_dir \
  "$REPO_ROOT/tutor_env/dev/frontend-app-learner-dashboard/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-learner-dashboard/src")"
CATALOG_SRC=""
for candidate in \
  "$REPO_ROOT/tutor_env/dev/frontend-app-discovery/src" \
  "$REPO_ROOT/tutor_env/dev/frontend-app-catalog/src" \
  "$REPO_ROOT/tutor_env/dev/frontend-app-course-catalog/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-discovery/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-catalog/src" \
  "$ULMO_SLOT_SOURCE_FALLBACK/frontend-app-course-catalog/src"
do
  if [[ -d "$candidate" ]]; then
    CATALOG_SRC="$candidate"
    break
  fi
done

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

check_slot_in_any_local_source() {
  local slot="$1"
  local found=0
  local source_dir
  shift

  for source_dir in "$@"; do
    [[ -d "$source_dir" ]] || continue
    if rg -qF "$slot" "$source_dir"; then
      found=1
      break
    fi
  done

  if [[ "$found" -eq 1 ]]; then
    pass "Slot exists in at least one local source checkout: $slot"
  else
    warn "Slot not found in available local source checkouts: $slot"
  fi
}

declare -A skipped_namespace_counts=()
AUTHORING_LEGACY_ONLY=0
if [[ -n "$AUTHORING_SRC" ]]; then
  authoring_slot_count="$(
    rg -o "org\\.openedx\\.frontend\\.authoring\\.[A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)*\\.v[0-9]+" "$AUTHORING_SRC" \
      | sed -E 's/.*://g' \
      | sort -u \
      | sed '/^$/d' \
      | wc -l \
      | tr -d ' '
  )"
  if [[ "$authoring_slot_count" -le 1 ]] && rg -qF "org.openedx.frontend.authoring.course_unit_sidebar.v1" "$AUTHORING_SRC"; then
    AUTHORING_LEGACY_ONLY=1
    warn "Authoring checkout appears legacy (only unit-sidebar slot detected); non-v1 authoring slot alignment checks will be skipped"
  fi
fi

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
      if [[ "$AUTHORING_LEGACY_ONLY" == "1" && "$slot" != "org.openedx.frontend.authoring.course_unit_sidebar.v1" ]]; then
        skipped_namespace_counts["authoring_legacy"]=$(( ${skipped_namespace_counts["authoring_legacy"]:-0} + 1 ))
      else
        check_slot_in_source "$slot" "$AUTHORING_SRC" "authoring"
      fi
      ;;
    org.openedx.frontend.catalog.*)
      if [[ -n "$CATALOG_SRC" ]]; then
        check_slot_in_source "$slot" "$CATALOG_SRC" "catalog"
      else
        skipped_namespace_counts["catalog"]=$(( ${skipped_namespace_counts["catalog"]:-0} + 1 ))
      fi
      ;;
    org.openedx.frontend.learner_dashboard.*)
      if [[ -d "$DASHBOARD_SRC" ]]; then
        check_slot_in_source "$slot" "$DASHBOARD_SRC" "learner-dashboard"
      else
        skipped_namespace_counts["learner_dashboard"]=$(( ${skipped_namespace_counts["learner_dashboard"]:-0} + 1 ))
      fi
      ;;
    org.openedx.frontend.layout.*)
      if [[ "$CHECK_LAYOUT_SLOT_EXISTENCE" == "1" ]]; then
        check_slot_in_any_local_source "$slot" \
          "$AUTHN_SRC" \
          "$ACCOUNT_SRC" \
          "$PROFILE_SRC" \
          "$LEARNING_SRC" \
          "$AUTHORING_SRC" \
          "$GRADEBOOK_SRC" \
          "$DASHBOARD_SRC" \
          "$CATALOG_SRC"
      else
        skipped_namespace_counts["layout_framework"]=$(( ${skipped_namespace_counts["layout_framework"]:-0} + 1 ))
      fi
      ;;
    *)
      warn "No local source-alignment check for slot (external/checkout not present): $slot"
      ;;
  esac
done <<<"$slots"

if [[ ${skipped_namespace_counts["catalog"]:-0} -gt 0 ]]; then
  warn "Catalog checkout missing; skipped ${skipped_namespace_counts["catalog"]} catalog slot alignment check(s)"
fi

if [[ ${skipped_namespace_counts["learner_dashboard"]:-0} -gt 0 ]]; then
  warn "Learner-dashboard checkout missing; skipped ${skipped_namespace_counts["learner_dashboard"]} dashboard slot alignment check(s)"
fi

if [[ ${skipped_namespace_counts["authoring_legacy"]:-0} -gt 0 ]]; then
  warn "Authoring checkout lacks modern slot surfaces; skipped ${skipped_namespace_counts["authoring_legacy"]} authoring slot alignment check(s)"
fi

if [[ ${skipped_namespace_counts["layout_framework"]:-0} -gt 0 ]]; then
  warn "Layout slot existence checks are disabled (CHECK_LAYOUT_SLOT_EXISTENCE=0); skipped ${skipped_namespace_counts["layout_framework"]} layout slot check(s)"
fi

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
