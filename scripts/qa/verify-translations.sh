#!/usr/bin/env bash
# @covers AC-CCR-010
# @spec: cross-cutting-requirements_spec.md
# Verify translation completeness for Mereka Academy OEP-58 locale support.
#
# Supported locales: en (primary), id, zh_CN, vi, fil
#
# Checks:
#   1. atlas.yml is present at repo root
#   2. TRANSLATION_WORKFLOW.md exists
#   3. sync-translations.sh exists and is executable
#   4. MFE locale directories exist for target languages
#   5. Non-English locale files have >= 80% key coverage vs English
#   6. Platform locale directory exists and contains .po files
#   7. Theme templates scanned for hardcoded English strings (warning only)
#
# Usage:
#   ./scripts/qa/verify-translations.sh [--offline]
#
# Modes:
#   --offline   Check locale file structure only (no network, safe for CI)
#
# Returns:
#   0  all checks pass (warnings do not block)
#   1  one or more FAIL checks
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

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0
WARN=0

pass() { echo -e "${GREEN}✓ PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}✗ FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}⊘ SKIP${NC}  $1"; SKIP=$((SKIP + 1)); }
warn() { echo -e "${YELLOW}⚠ WARN${NC}  $1"; WARN=$((WARN + 1)); }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OFFLINE=false
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=true ;;
    *)
      echo "Usage: $0 [--offline]"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
MFE_LOCALE_DIR="${REPO_ROOT}/infrastructure/tutor/themes/mereka/mfe"
PLATFORM_LOCALE_DIR="${REPO_ROOT}/tutor_env/env/build/openedx/locale"
THEME_DIR="${REPO_ROOT}/infrastructure/tutor/themes/mereka"

# OEP-58 supported locales (en = source, others require >= 80% coverage)
TARGET_LANGS=("en" "id" "zh_CN" "vi" "fil")
COVERAGE_THRESHOLD=80

# ---------------------------------------------------------------------------
# Helper: count keys in a flat or nested JSON file
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
except Exception:
    print(0)
PY
}

# ---------------------------------------------------------------------------
# Section 0: Workflow infrastructure (atlas.yml, docs, sync script)
# ---------------------------------------------------------------------------
echo "=== Section 0: Translation workflow infrastructure ==="

# atlas.yml at repo root
if [[ -f "${REPO_ROOT}/atlas.yml" ]]; then
  pass "atlas.yml present at repo root"
else
  fail "atlas.yml missing from repo root (required for OEP-58 atlas pull)"
fi

# TRANSLATION_WORKFLOW.md
if [[ -f "${REPO_ROOT}/docs/ops/runbooks/TRANSLATION_WORKFLOW.md" ]]; then
  pass "docs/ops/runbooks/TRANSLATION_WORKFLOW.md exists"
else
  fail "docs/ops/runbooks/TRANSLATION_WORKFLOW.md missing"
fi

# sync-translations.sh is present and executable
SYNC_SCRIPT="${REPO_ROOT}/scripts/infra/sync-translations.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
  if [[ -x "$SYNC_SCRIPT" ]]; then
    pass "scripts/infra/sync-translations.sh exists and is executable"
  else
    fail "scripts/infra/sync-translations.sh exists but is not executable"
  fi
else
  fail "scripts/infra/sync-translations.sh missing"
fi

# CI workflow for translation validation
if [[ -f "${REPO_ROOT}/.github/workflows/translation-check.yml" ]]; then
  pass ".github/workflows/translation-check.yml present"
else
  warn ".github/workflows/translation-check.yml missing (CI validation not configured)"
fi

echo ""

# ---------------------------------------------------------------------------
# Section 1: MFE locale directories exist
# ---------------------------------------------------------------------------
echo "=== Section 1: MFE locale directories ==="

if [[ -d "$MFE_LOCALE_DIR" ]]; then
  pass "MFE locale root exists: ${MFE_LOCALE_DIR}"
else
  fail "MFE locale root missing: ${MFE_LOCALE_DIR}"
  fail "  Run: ./scripts/infra/sync-translations.sh --dry-run  (then live pull)"
fi

# Check that at least one app locale directory has en and each non-English locale
EN_DIRS=0
while IFS= read -r -d '' en_dir; do
  EN_DIRS=$((EN_DIRS + 1))
done < <(find "$MFE_LOCALE_DIR" -type d -name "en" -print0 2>/dev/null)

if [[ "$EN_DIRS" -gt 0 ]]; then
  pass "MFE en locale directories found: ${EN_DIRS}"
else
  warn "No MFE en locale directories found under ${MFE_LOCALE_DIR}"
fi

# Check each non-en OEP-58 locale directory is present
for lang in "${TARGET_LANGS[@]}"; do
  [[ "$lang" == "en" ]] && continue
  lang_dir_count=0
  while IFS= read -r -d '' d; do
    lang_dir_count=$((lang_dir_count + 1))
  done < <(find "$MFE_LOCALE_DIR" -type d -name "$lang" -print0 2>/dev/null)
  if [[ "$lang_dir_count" -gt 0 ]]; then
    pass "MFE ${lang} locale directories found: ${lang_dir_count}"
  else
    warn "No MFE ${lang} locale directories found (translations not pulled yet?)"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Section 2: MFE locale key coverage (all non-en >= COVERAGE_THRESHOLD% of en)
# ---------------------------------------------------------------------------
echo "=== Section 2: MFE OEP-58 locale key coverage ==="

ANY_MFE_CHECKED=false

while IFS= read -r -d '' en_file; do
  mfe_app_dir="$(dirname "$(dirname "$en_file")")"
  app_name="$(basename "$mfe_app_dir")"

  en_count="$(count_json_keys "$en_file")"
  ANY_MFE_CHECKED=true

  if [[ "$en_count" -eq 0 ]]; then
    warn "${app_name}: en/messages.json has 0 keys (empty or invalid)"
    continue
  fi

  for lang in "${TARGET_LANGS[@]}"; do
    [[ "$lang" == "en" ]] && continue
    lang_file="${mfe_app_dir}/${lang}/messages.json"

    if [[ ! -f "$lang_file" ]]; then
      fail "${app_name}: ${lang}/messages.json missing"
      continue
    fi

    lang_count="$(count_json_keys "$lang_file")"
    coverage=$(( lang_count * 100 / en_count ))

    if [[ "$coverage" -ge "$COVERAGE_THRESHOLD" ]]; then
      pass "${app_name}/${lang}: ${lang_count}/${en_count} keys (${coverage}%)"
    else
      fail "${app_name}/${lang}: ${lang_count}/${en_count} keys (${coverage}% < ${COVERAGE_THRESHOLD}%)"
    fi
  done
done < <(find "$MFE_LOCALE_DIR" -path "*/en/messages.json" -print0 2>/dev/null)

if [[ "$ANY_MFE_CHECKED" == "false" ]]; then
  skip "No MFE en/messages.json files found — run sync-translations.sh first"
fi

echo ""

# ---------------------------------------------------------------------------
# Section 3: Platform locale files
# ---------------------------------------------------------------------------
echo "=== Section 3: Platform (LMS/CMS) locale files ==="

if [[ -d "$PLATFORM_LOCALE_DIR" ]]; then
  pass "Platform locale directory exists: ${PLATFORM_LOCALE_DIR}"

  for lang in "${TARGET_LANGS[@]}"; do
    [[ "$lang" == "en" ]] && continue
    lang_dir="${PLATFORM_LOCALE_DIR}/${lang}"
    if [[ -d "$lang_dir" ]]; then
      po_count=$(find "$lang_dir" -name "*.po" 2>/dev/null | wc -l)
      if [[ "$po_count" -gt 0 ]]; then
        pass "Platform ${lang}: ${po_count} .po file(s) found"
      else
        warn "Platform ${lang}: directory exists but no .po files found"
      fi
    else
      fail "Platform ${lang}: locale directory missing (${lang_dir})"
    fi
  done
else
  skip "Platform locale directory not found (${PLATFORM_LOCALE_DIR}) — requires tutor build"
fi

echo ""

# ---------------------------------------------------------------------------
# Section 4: Theme template scan for hardcoded English strings (warning only)
# ---------------------------------------------------------------------------
echo "=== Section 4: Theme template hardcoded strings scan ==="

if [[ ! -d "$THEME_DIR" ]]; then
  skip "Theme directory not found: ${THEME_DIR}"
else
  # Look for template files
  TEMPLATE_FILES=()
  while IFS= read -r -d '' f; do
    TEMPLATE_FILES+=("$f")
  done < <(find "$THEME_DIR" -type f \( -name "*.html" -o -name "*.jinja2" \) -print0 2>/dev/null)

  if [[ "${#TEMPLATE_FILES[@]}" -eq 0 ]]; then
    skip "No .html/.jinja2 templates found in theme directory"
  else
    pass "Theme templates found: ${#TEMPLATE_FILES[@]} file(s)"

    # Patterns indicating text that is likely hardcoded English and not wrapped in
    # a trans/gettext tag. We look for text content outside of tag attributes.
    # This is a heuristic, not a parser — false positives are expected.
    HARDCODED_HITS=0
    SCANNED=0

    for tmpl in "${TEMPLATE_FILES[@]}"; do
      SCANNED=$((SCANNED + 1))
      # Lines with visible English words NOT inside a trans block or gettext call
      # Heuristic: look for lines with bare English words (capitalized, >= 4 chars)
      # that are NOT inside {% trans %}, _( ), gettext(
      hits=$(
        grep -nE '[A-Z][a-z]{3,}' "$tmpl" 2>/dev/null \
          | grep -vE '(trans|gettext|_\(|{%|<!--|\bclass=|\bhref=|\bsrc=|\balt=|\baria-|\bdata-|\bid=|\bname=|\btype=|<!--)' \
          | wc -l
      ) || hits=0
      HARDCODED_HITS=$((HARDCODED_HITS + hits))
    done

    if [[ "$HARDCODED_HITS" -gt 0 ]]; then
      warn "~${HARDCODED_HITS} potential hardcoded English string(s) in ${SCANNED} template(s)"
      warn "  These are warnings only — review manually for i18n compliance"
      warn "  Use {% trans %} or _() to mark strings for translation"
    else
      pass "No obvious hardcoded English strings detected in theme templates"
    fi
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "==================================================================="
echo "Summary: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP} WARN=${WARN}"
echo "==================================================================="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Some checks failed. Run the following to pull translations:"
  echo "  ./scripts/infra/sync-translations.sh"
  echo "  ./scripts/infra/sync-translations.sh --check"
  exit 1
fi

exit 0
