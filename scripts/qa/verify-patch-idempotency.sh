#!/usr/bin/env bash
# @covers AC-TCR-009
# @spec: tutor-configuration-resilience_spec.md
# Verify that apply-patches.sh is idempotent: running it twice produces
# identical output with no duplicate entries.
#
# Modes:
#   --tutor    (default) Requires TUTOR_ROOT with generated Tutor env
#   --offline  Checks existing patched files for duplicate markers only
#   --dry-run  Lists what would be checked without running anything
#
# Usage:
#   ./scripts/qa/verify-patch-idempotency.sh [--tutor|--offline|--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

# ---------------------------------------------------------------------------
# Parse mode
# ---------------------------------------------------------------------------
MODE="tutor"
if [[ "${1:-}" == "--offline" ]]; then
  MODE="offline"
elif [[ "${1:-}" == "--dry-run" ]]; then
  MODE="dry-run"
elif [[ "${1:-}" == "--tutor" ]]; then
  MODE="tutor"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--tutor|--offline|--dry-run]"
  exit 1
fi

# ---------------------------------------------------------------------------
# Patch target files (relative to TUTOR_ROOT or REPO_ROOT/tutor_env)
# ---------------------------------------------------------------------------
TUTOR_ENV="${TUTOR_ROOT:-${REPO_ROOT}/tutor_env}"

PATCH_TARGETS=(
  "env/local/docker-compose.yml"
  "env/plugins/mfe/build/mfe/Dockerfile"
  "env/plugins/mfe/build/mfe/mereka/env.config.jsx"
  "env/build/openedx/Dockerfile"
  "env/apps/caddy/Caddyfile"
  "env/apps/nginx/lms.conf"
  "env/apps/openedx/settings/lms/production.py"
  "env/build/openedx/settings/lms/assets.py"
  "env/build/openedx/settings/cms/assets.py"
  "env/build/openedx/edx-platform/webpack.prod.config.js"
)

# ---------------------------------------------------------------------------
# Duplicate markers to check in offline/tutor mode
# These are sentinels that should appear exactly once (or a known count).
# Format: "file_suffix|pattern|max_count|description"
# ---------------------------------------------------------------------------
DUPLICATE_CHECKS=(
  "production.py|INSTALLED_APPS.append('mfe_oauth_fix')|1|mfe_oauth_fix INSTALLED_APPS entry"
  "production.py|INSTALLED_APPS.append('openedx_prometheus')|1|openedx_prometheus INSTALLED_APPS entry"
  "production.py|INSTALLED_APPS.append('mereka_tenancy')|1|mereka_tenancy INSTALLED_APPS entry"
  "production.py|INSTALLED_APPS.insert(0, 'django_prometheus')|1|django_prometheus INSTALLED_APPS entry"
  "production.py|PrometheusBeforeMiddleware|2|Prometheus before middleware (guard + insert)"
  "production.py|PrometheusAfterMiddleware|2|Prometheus after middleware (guard + append)"
  "production.py|TenantResolutionMiddleware|4|Tenant resolution middleware (guard + insert + fallback)"
  "production.py|DEFAULT_SITE_THEME|1|Default site theme setting"
  "production.py|# Force MFE-only discussions (greenfield|1|MFE discussions config block"
  "production.py|DISCUSSIONS_MFE_ENABLED = True|1|MFE discussions enabled flag"
  "openedx/Dockerfile|ENV PYTHONPATH=/openedx/edx-platform|2|PYTHONPATH env var"
  'openedx/Dockerfile|ENV NODE_OPTIONS="--max-old-space-size=6144"|2|NODE_OPTIONS env var'
  "openedx/Dockerfile|ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none|2|REQUIRE_BUILD_PROFILE_OPTIMIZE env var"
  "openedx/Dockerfile|pip install -e /openedx/mfe_oauth_fix|1|mfe_oauth_fix pip install"
  "openedx/Dockerfile|pip install -e /openedx/openedx_prometheus|1|openedx_prometheus pip install"
  "openedx/Dockerfile|pip install django-prometheus|1|django-prometheus pip install"
  "openedx/Dockerfile|mereka-overrides.css|4|mereka CSS copy block"
  "docker-compose.yml|mysql-native-password=ON|1|MySQL native password mode"
  "docker-compose.yml|MYSQL_ROOT_HOST|1|MySQL root host"
  "Caddyfile|academy.biji-biji.com|1|Biji-Biji domain in Caddy"
  "lms.conf|academy.biji-biji.com|1|Biji-Biji domain in nginx"
  "env.config.jsx|theme-source/mereka.scss|1|MFE theme SCSS import"
  "env.config.jsx|const MerekaFooter|1|MFE Mereka footer component"
)

# ---------------------------------------------------------------------------
# Dry-run mode: just list what would be checked
# ---------------------------------------------------------------------------
if [[ "$MODE" == "dry-run" ]]; then
  echo -e "${BLUE}=== Patch Idempotency Check (dry-run) ===${NC}"
  echo ""
  echo "Patch target files to compare (under ${TUTOR_ENV}):"
  for target in "${PATCH_TARGETS[@]}"; do
    full_path="${TUTOR_ENV}/${target}"
    if [[ -f "$full_path" ]]; then
      echo "  [exists]  $target"
    else
      echo "  [missing] $target"
    fi
  done
  echo ""
  echo "Duplicate marker checks (${#DUPLICATE_CHECKS[@]} patterns):"
  for check in "${DUPLICATE_CHECKS[@]}"; do
    IFS='|' read -r suffix pattern max_count desc <<< "$check"
    echo "  ${desc}: '${pattern}' in *${suffix} (max ${max_count})"
  done
  echo ""
  echo "No changes made."
  exit 0
fi

# ---------------------------------------------------------------------------
# check_duplicates: scan files for markers that should not be duplicated
# ---------------------------------------------------------------------------
check_duplicates() {
  local base_dir="$1"
  echo -e "\n${BLUE}=== Checking for duplicate patch markers ===${NC}"

  for check in "${DUPLICATE_CHECKS[@]}"; do
    IFS='|' read -r suffix pattern max_count desc <<< "$check"

    # Find matching file
    local target_file=""
    for target in "${PATCH_TARGETS[@]}"; do
      if [[ "$target" == *"$suffix" ]]; then
        target_file="${base_dir}/${target}"
        break
      fi
    done

    if [[ -z "$target_file" || ! -f "$target_file" ]]; then
      skip "${desc} (file not found)"
      continue
    fi

    local count
    count=$(grep -cF "$pattern" "$target_file" 2>/dev/null || true)

    if [[ "$count" -le "$max_count" ]]; then
      pass "${desc} (count=${count}, max=${max_count})"
    else
      fail "${desc} (count=${count}, expected <=${max_count}) in ${target_file}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Offline mode: check existing files for duplicates only
# ---------------------------------------------------------------------------
if [[ "$MODE" == "offline" ]]; then
  echo -e "${BLUE}=== Patch Idempotency Check (offline) ===${NC}"
  echo "Scanning ${TUTOR_ENV} for duplicate markers..."

  if [[ ! -d "$TUTOR_ENV/env" ]]; then
    echo -e "${RED}ERROR: Tutor environment not found at ${TUTOR_ENV}/env${NC}"
    echo "Use --tutor mode with TUTOR_ROOT set, or run 'tutor config save' first."
    exit 1
  fi

  check_duplicates "$TUTOR_ENV"

  echo ""
  echo -e "${BLUE}=== Summary ===${NC}"
  echo -e "PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"
  [[ "$FAILED" -eq 0 ]] && exit 0 || exit 1
fi

# ---------------------------------------------------------------------------
# Tutor mode: run apply-patches.sh twice, compare checksums + check duplicates
# ---------------------------------------------------------------------------
echo -e "${BLUE}=== Patch Idempotency Check (tutor) ===${NC}"

if [[ ! -d "$TUTOR_ENV/env" ]]; then
  echo -e "${RED}ERROR: Tutor environment not found at ${TUTOR_ENV}/env${NC}"
  echo "Run 'tutor config save' first, then apply-patches.sh, before this test."
  exit 1
fi

APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
if [[ ! -x "$APPLY_PATCHES" ]]; then
  echo -e "${RED}ERROR: apply-patches.sh not found or not executable${NC}"
  exit 1
fi

CHECKSUM_DIR=$(mktemp -d)
trap 'rm -rf "$CHECKSUM_DIR"' EXIT

# Compute checksums of all patch target files
compute_checksums() {
  local output_file="$1"
  local found=0
  for target in "${PATCH_TARGETS[@]}"; do
    local full_path="${TUTOR_ENV}/${target}"
    if [[ -f "$full_path" ]]; then
      sha256sum "$full_path" >> "$output_file"
      found=$((found + 1))
    fi
  done
  echo "$found"
}

echo ""
echo "Step 1: Running apply-patches.sh (first run)..."
"$APPLY_PATCHES"
echo ""

echo "Step 2: Capturing checksums after first run..."
FIRST_COUNT=$(compute_checksums "${CHECKSUM_DIR}/run1.txt")
echo "  Checksummed ${FIRST_COUNT} files"

echo ""
echo "Step 3: Running apply-patches.sh (second run)..."
"$APPLY_PATCHES"
echo ""

echo "Step 4: Capturing checksums after second run..."
SECOND_COUNT=$(compute_checksums "${CHECKSUM_DIR}/run2.txt")
echo "  Checksummed ${SECOND_COUNT} files"

# Compare checksums
echo ""
echo -e "${BLUE}=== Comparing checksums ===${NC}"

if diff -u "${CHECKSUM_DIR}/run1.txt" "${CHECKSUM_DIR}/run2.txt" > "${CHECKSUM_DIR}/diff.txt" 2>&1; then
  pass "All ${FIRST_COUNT} files identical after second apply-patches.sh run"
else
  fail "Files changed between first and second run:"
  # Show which files differ
  while IFS= read -r line; do
    if [[ "$line" == "+"* && "$line" != "+++"* ]]; then
      echo -e "  ${RED}${line}${NC}"
    elif [[ "$line" == "-"* && "$line" != "---"* ]]; then
      echo -e "  ${YELLOW}${line}${NC}"
    fi
  done < "${CHECKSUM_DIR}/diff.txt"
fi

# Also run duplicate marker checks
check_duplicates "$TUTOR_ENV"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}All idempotency checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${FAILED} idempotency check(s) failed.${NC}"
  echo ""
  echo "Common causes:"
  echo "  - Patch function missing 'if X in text: return text' guard"
  echo "  - String replacement target matches its own output"
  echo "  - Append without 'not in' check"
  echo ""
  echo "Fix in: infrastructure/tutor/apply-patches.sh"
  exit 1
fi
