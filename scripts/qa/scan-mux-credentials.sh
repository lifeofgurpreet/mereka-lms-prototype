#!/usr/bin/env bash
# @covers AC-021
# @spec: video-pipeline-delivery_spec.md
# Scan codebase for hardcoded Mux credentials
# AC-021: Ensure no hardcoded MUX tokens in code
#
# Usage:
#   ./scripts/qa/scan-mux-credentials.sh [--path <directory>]
#
# Returns:
#   0 if no hardcoded credentials found
#   1 if hardcoded credentials detected

set -euo pipefail

# Source shared config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Configuration
# =============================================================================
SCAN_PATH="."
EXCLUDE_DIRS=(
  ".git"
  "node_modules"
  "tutor_env"
  "var"
  ".venv"
  "__pycache__"
  "build"
  "dist"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      SCAN_PATH="$2"
      shift 2
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# =============================================================================
# Patterns to detect
# =============================================================================
# Mux token patterns (avoiding false positives from env var references)
MUX_PATTERNS=(
  # Mux token ID format: 8-4-4-4-12 hex characters
  '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'

  # Mux secret format (base64-like, typically 40+ chars)
  'MUX_TOKEN_SECRET.*=.*["\x27][A-Za-z0-9+/]{40,}["\x27]'
  'MUX_TOKEN_ID.*=.*["\x27][0-9a-f-]{36}["\x27]'

  # Assignment patterns (avoid env var references)
  'mux.*token.*=.*["\x27][A-Za-z0-9_-]{20,}["\x27]'
)

# Allowed patterns (env var references, config examples, docs)
ALLOWED_PATTERNS=(
  'os\.environ\.get'
  'process\.env'
  '\$\{.*\}'
  'export MUX_TOKEN'
  'MUX_TOKEN.*=.*""'
  'MUX_TOKEN.*=.*'\'\'
  'your-token-id'
  'your-token-secret'
  'example\.com'
  '# .*MUX_TOKEN'
  '<!--.*MUX_TOKEN.*-->'
)

# =============================================================================
# Build find command exclude args
# =============================================================================
build_exclude_args() {
  local exclude_args=()
  for dir in "${EXCLUDE_DIRS[@]}"; do
    exclude_args+=(-path "*/${dir}" -prune -o)
  done
  printf '%s ' "${exclude_args[@]}"
}

# =============================================================================
# Scan functions
# =============================================================================
scan_for_credentials() {
  info "Scanning ${SCAN_PATH} for hardcoded Mux credentials..."
  echo

  local found_issues=0
  local exclude_args
  exclude_args=$(build_exclude_args)

  # Search for each pattern
  for pattern in "${MUX_PATTERNS[@]}"; do
    # shellcheck disable=SC2086
    local matches
    matches=$(find "${SCAN_PATH}" ${exclude_args} -type f \
      -name "*.py" -o \
      -name "*.js" -o \
      -name "*.ts" -o \
      -name "*.jsx" -o \
      -name "*.tsx" -o \
      -name "*.sh" -o \
      -name "*.yaml" -o \
      -name "*.yml" -o \
      -name "*.json" \
      | xargs grep -Hn -E "${pattern}" 2>/dev/null || true)

    if [[ -n "${matches}" ]]; then
      # Filter out allowed patterns
      local filtered_matches=""
      while IFS= read -r line; do
        local is_allowed=0
        for allowed in "${ALLOWED_PATTERNS[@]}"; do
          if echo "${line}" | grep -qE "${allowed}"; then
            is_allowed=1
            break
          fi
        done

        if [[ "${is_allowed}" -eq 0 ]]; then
          filtered_matches+="${line}"$'\n'
        fi
      done <<< "${matches}"

      if [[ -n "${filtered_matches}" ]]; then
        warn "Potential hardcoded credentials (pattern: ${pattern}):"
        echo "${filtered_matches}"
        echo
        found_issues=1
      fi
    fi
  done

  # Check Python scripts specifically for proper env var usage
  info "Checking Python scripts for environment variable usage..."
  local python_scripts
  python_scripts=$(find "${SCAN_PATH}" -type f -name "*.py" 2>/dev/null || true)

  if [[ -n "${python_scripts}" ]]; then
    local scripts_without_env=()
    while IFS= read -r script; do
      if [[ -z "${script}" ]]; then
        continue
      fi

      # Check if script references MUX_TOKEN but doesn't use os.environ.get
      if grep -q "MUX_TOKEN" "${script}" 2>/dev/null; then
        # Verify it uses proper env var access
        if ! grep -q "os\.environ\.get.*MUX_TOKEN\|os\.getenv.*MUX_TOKEN\|environ\[.*MUX_TOKEN" "${script}" 2>/dev/null; then
          # But exclude doc strings and comments
          if ! grep "MUX_TOKEN" "${script}" | grep -qE '^\s*(#|"""|\x27\x27\x27)'; then
            scripts_without_env+=("${script}")
          fi
        fi
      fi
    done <<< "${python_scripts}"

    if [[ ${#scripts_without_env[@]} -gt 0 ]]; then
      warn "Python scripts referencing MUX_TOKEN without os.environ.get:"
      for script in "${scripts_without_env[@]}"; do
        echo "  - ${script}"
      done
      echo
      found_issues=1
    fi
  fi

  return "${found_issues}"
}

# =============================================================================
# Main
# =============================================================================
main() {
  if ! scan_for_credentials; then
    echo
    info "✅ No hardcoded Mux credentials detected"
    return 0
  else
    echo
    error "❌ Potential hardcoded credentials found - review output above"
    error "    Credentials should be loaded from environment variables only"
    return 1
  fi
}

main "$@"
