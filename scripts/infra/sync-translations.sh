#!/usr/bin/env bash
# Sync Open edX translations using openedx-atlas CLI.
#
# Pulls platform (LMS/CMS) and MFE locale files for EN + MS (Malay).
#
# Usage:
#   ./scripts/infra/sync-translations.sh [--dry-run] [--check]
#
# Modes:
#   (default)   Pull translations from Transifex via openedx-atlas
#   --dry-run   Show what would be synced without writing files
#   --check     Verify locale file completeness (ms >= 80% key coverage vs en)
#
# Requirements:
#   openedx-atlas >= 0.6.0  (pip install openedx-atlas)
#   Transifex API token in TRANSIFEX_TOKEN env var (for live pull only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DRY_RUN=false
CHECK=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --check)   CHECK=true ;;
    *)
      error "Unknown argument: $arg"
      echo "Usage: $0 [--dry-run] [--check]"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Target languages and locale directories
# ---------------------------------------------------------------------------
TARGET_LANGS=("en" "ms")

# Platform locale root (inside tutor environment / openedx checkout)
PLATFORM_LOCALE_DIR="${REPO_ROOT}/tutor_env/env/build/openedx/locale"
# MFE locale root (built into theme mfe directory)
MFE_LOCALE_DIR="${REPO_ROOT}/infrastructure/tutor/themes/mereka/mfe"

# ---------------------------------------------------------------------------
# Helper: check_tool_installed
# ---------------------------------------------------------------------------
check_tool_installed() {
  if ! command -v openedx-atlas >/dev/null 2>&1; then
    error "openedx-atlas not found."
    echo ""
    echo "  Install it with:"
    echo "    pip install openedx-atlas"
    echo ""
    echo "  Or inside the project venv:"
    echo "    source .venv/bin/activate"
    echo "    pip install openedx-atlas"
    exit 1
  fi
  info "openedx-atlas found: $(openedx-atlas --version 2>/dev/null || echo 'version unknown')"
}

# ---------------------------------------------------------------------------
# Helper: count JSON keys in a locale file (flat or nested)
# ---------------------------------------------------------------------------
count_json_keys() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys

def flatten(obj, prefix=""):
    keys = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            keys += flatten(v, prefix + k + ".")
    else:
        keys.append(prefix.rstrip("."))
    return keys

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    print(len(flatten(data)))
except Exception as e:
    print(0)
PY
}

# ---------------------------------------------------------------------------
# MODE: --check  (locale completeness verification)
# ---------------------------------------------------------------------------
if [[ "$CHECK" == "true" ]]; then
  echo "== Translation Completeness Check =="
  echo "   Target languages : ${TARGET_LANGS[*]}"
  echo "   Coverage threshold: 80%"
  echo ""

  PASS=0
  FAIL=0
  WARN=0

  # Check MFE locale files
  echo "--- MFE locale files (${MFE_LOCALE_DIR}) ---"
  if [[ ! -d "$MFE_LOCALE_DIR" ]]; then
    warn "MFE locale directory not found: ${MFE_LOCALE_DIR}"
    WARN=$((WARN + 1))
  else
    # Find all MFE apps that have an 'en' locale JSON
    while IFS= read -r -d '' en_file; do
      mfe_app_dir="$(dirname "$(dirname "$en_file")")"
      app_name="$(basename "$mfe_app_dir")"
      en_key_count="$(count_json_keys "$en_file")"

      if [[ "$en_key_count" -eq 0 ]]; then
        warn "${app_name}: en/messages.json is empty or unparseable"
        WARN=$((WARN + 1))
        continue
      fi

      echo "  ${app_name}: en has ${en_key_count} keys"

      # Check each non-en target language
      for lang in "${TARGET_LANGS[@]}"; do
        [[ "$lang" == "en" ]] && continue
        ms_file="${mfe_app_dir}/${lang}/messages.json"
        if [[ ! -f "$ms_file" ]]; then
          warn "  ${app_name}/${lang}/messages.json missing"
          WARN=$((WARN + 1))
          continue
        fi
        ms_key_count="$(count_json_keys "$ms_file")"
        if [[ "$en_key_count" -gt 0 ]]; then
          coverage=$(( ms_key_count * 100 / en_key_count ))
        else
          coverage=0
        fi
        if [[ "$coverage" -ge 80 ]]; then
          echo -e "  ${GREEN}PASS${NC}  ${app_name}/${lang}: ${ms_key_count}/${en_key_count} keys (${coverage}%)"
          PASS=$((PASS + 1))
        else
          echo -e "  ${RED}FAIL${NC}  ${app_name}/${lang}: ${ms_key_count}/${en_key_count} keys (${coverage}% < 80%)"
          FAIL=$((FAIL + 1))
        fi
      done
    done < <(find "$MFE_LOCALE_DIR" -path "*/en/messages.json" -print0 2>/dev/null)

    if [[ "$PASS" -eq 0 && "$FAIL" -eq 0 && "$WARN" -eq 0 ]]; then
      warn "No MFE locale files found under ${MFE_LOCALE_DIR}"
      WARN=$((WARN + 1))
    fi
  fi

  echo ""
  echo "--- Platform locale files (${PLATFORM_LOCALE_DIR}) ---"
  if [[ ! -d "$PLATFORM_LOCALE_DIR" ]]; then
    warn "Platform locale directory not found: ${PLATFORM_LOCALE_DIR}"
    warn "Run './scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast' or pull translations first."
    WARN=$((WARN + 1))
  else
    for lang in "${TARGET_LANGS[@]}"; do
      [[ "$lang" == "en" ]] && continue
      locale_dir="${PLATFORM_LOCALE_DIR}/${lang}"
      if [[ -d "$locale_dir" ]]; then
        po_count=$(find "$locale_dir" -name "*.po" 2>/dev/null | wc -l)
        if [[ "$po_count" -gt 0 ]]; then
          echo -e "  ${GREEN}PASS${NC}  platform/${lang}: ${po_count} .po file(s) present"
          PASS=$((PASS + 1))
        else
          warn "  platform/${lang}: directory exists but no .po files"
          WARN=$((WARN + 1))
        fi
      else
        echo -e "  ${RED}FAIL${NC}  platform/${lang}: locale directory missing (${locale_dir})"
        FAIL=$((FAIL + 1))
      fi
    done
  fi

  echo ""
  echo "Summary: PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"
  [[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
fi

# ---------------------------------------------------------------------------
# MODE: --dry-run  or default (live sync)
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
  echo "== Translation Sync (DRY RUN) =="
  echo ""
  echo "Would run the following commands:"
  echo ""
  echo "  openedx-atlas pull \\"
  echo "    --repository openedx/openedx-translations \\"
  echo "    --branch main \\"
  echo "    --languages en,ms \\"
  echo "    --output-dir ${PLATFORM_LOCALE_DIR}"
  echo ""
  echo "  (for each MFE app):"
  echo "  openedx-atlas pull-mfe \\"
  echo "    --repository openedx/openedx-translations \\"
  echo "    --branch main \\"
  echo "    --languages en,ms \\"
  echo "    --output-dir ${MFE_LOCALE_DIR}/<app>"
  echo ""
  echo "  Target languages : ${TARGET_LANGS[*]}"
  echo "  Platform output  : ${PLATFORM_LOCALE_DIR}"
  echo "  MFE output       : ${MFE_LOCALE_DIR}"
  echo ""
  info "Dry run complete. No files written."
  exit 0
fi

# ---------------------------------------------------------------------------
# Live sync
# ---------------------------------------------------------------------------
check_tool_installed

if [[ -z "${TRANSIFEX_TOKEN:-}" ]]; then
  error "TRANSIFEX_TOKEN is not set."
  echo ""
  echo "  Export your Transifex API token:"
  echo "    export TRANSIFEX_TOKEN=<your_token>"
  echo ""
  echo "  Or run in dry-run mode to preview:"
  echo "    $0 --dry-run"
  exit 1
fi

echo "== Syncing Open edX Translations =="
echo "   Languages : ${TARGET_LANGS[*]}"
echo "   Source    : openedx/openedx-translations @ main"
echo ""

LANG_CSV="$(IFS=,; echo "${TARGET_LANGS[*]}")"

# --- Platform (LMS/CMS) translations ---
echo "--- Platform (LMS/CMS) translations ---"
mkdir -p "$PLATFORM_LOCALE_DIR"

info "Pulling platform translations..."
openedx-atlas pull \
  --repository openedx/openedx-translations \
  --branch main \
  --languages "$LANG_CSV" \
  --output-dir "$PLATFORM_LOCALE_DIR"

info "Platform translations synced to: ${PLATFORM_LOCALE_DIR}"
echo ""

# --- MFE locale files ---
echo "--- MFE locale files ---"
mkdir -p "$MFE_LOCALE_DIR"

# Known MFE apps that ship locale files via openedx-translations
MFE_APPS=(
  "frontend-app-authn"
  "frontend-app-learning"
  "frontend-app-profile"
  "frontend-app-account"
  "frontend-app-course-authoring"
  "frontend-app-discussions"
  "frontend-app-gradebook"
)

for app in "${MFE_APPS[@]}"; do
  info "Pulling MFE translations: ${app}"
  app_out="${MFE_LOCALE_DIR}/${app}"
  mkdir -p "$app_out"
  openedx-atlas pull \
    --repository openedx/openedx-translations \
    --branch main \
    --filter "src/i18n/messages/${app}" \
    --languages "$LANG_CSV" \
    --output-dir "$app_out" \
    || warn "  ${app}: pull failed (may not have translations yet)"
done

echo ""
info "Translation sync complete."
echo ""
echo "Next steps:"
echo "  1. Verify completeness : $0 --check"
echo "  2. Rebuild MFE images  : ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
echo "  3. Restart services    : tutor local restart mfe"
