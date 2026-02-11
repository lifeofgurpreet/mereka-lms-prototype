#!/usr/bin/env bash
# @covers AC-HUB-005, AC-HUB-021, AC-HUB-022
# @spec: external-registration-hubspot_spec.md
# Scan codebase for hardcoded HubSpot/SendGrid credentials and security issues
# AC-HUB-005: OAuth only (no hardcoded PAT)
# AC-HUB-022: No plaintext passwords/keys/emails in logs
#
# Checks:
#   - No hardcoded HubSpot PATs (pat-na1-*, pat-eu1-*)
#   - No hardcoded SendGrid API keys (SG.*)
#   - No committed .env files with secrets
#   - No console.log with password/token patterns
#   - HUBSPOT_PAT usage flagged (spec requires OAuth, not PAT)
#
# Usage:
#   ./scripts/qa/scan-hubspot-credentials.sh [--path <directory>]
#
# Returns:
#   0 if no hardcoded credentials found
#   1 if security issues detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

SCAN_PATH="${1:-services/hubspot-webhook}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
failures=0

# =============================================================================
# Check 1: Hardcoded HubSpot PATs
# =============================================================================
check_hardcoded_pats() {
  info "Checking for hardcoded HubSpot PATs..."

  local matches
  matches=$(grep -rn 'pat-na1-\|pat-eu1-' "${SCAN_PATH}" \
    --include="*.js" --include="*.ts" --include="*.py" \
    --include="*.yaml" --include="*.yml" --include="*.json" \
    --include="*.env" --include="*.sh" \
    2>/dev/null | grep -v 'node_modules' | grep -v '\.example' | grep -v 'README' || true)

  if [[ -n "${matches}" ]]; then
    error "  Hardcoded HubSpot PAT found:"
    echo "${matches}" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    info "  No hardcoded HubSpot PATs found"
  fi
}

# =============================================================================
# Check 2: Hardcoded SendGrid API keys
# =============================================================================
check_sendgrid_keys() {
  info "Checking for hardcoded SendGrid API keys..."

  local matches
  matches=$(grep -rn 'SG\.[A-Za-z0-9_-]\{20,\}' "${SCAN_PATH}" \
    --include="*.js" --include="*.ts" --include="*.py" \
    --include="*.yaml" --include="*.yml" --include="*.json" \
    --include="*.env" --include="*.sh" \
    2>/dev/null | grep -v 'node_modules' | grep -v '\.example' | grep -v 'README' || true)

  if [[ -n "${matches}" ]]; then
    error "  Hardcoded SendGrid API key found:"
    echo "${matches}" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    info "  No hardcoded SendGrid keys found"
  fi
}

# =============================================================================
# Check 3: Committed .env files with secrets
# =============================================================================
check_committed_env_files() {
  info "Checking for committed .env files with secrets..."

  local env_files
  env_files=$(find "${REPO_ROOT}" -name '.env' -not -name '.env.example' \
    -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null || true)

  if [[ -n "${env_files}" ]]; then
    while IFS= read -r env_file; do
      if [[ -z "${env_file}" ]]; then continue; fi

      # Check if file is tracked by git
      if git ls-files --error-unmatch "${env_file}" &>/dev/null; then
        # Check if it contains actual secret values (not empty or placeholder)
        if grep -qE '(PAT|SECRET|KEY|TOKEN|PASSWORD)=.{8,}' "${env_file}" 2>/dev/null; then
          error "  Committed .env with secrets: ${env_file}"
          failures=$((failures + 1))
        fi
      fi
    done <<< "${env_files}"
  fi

  if [[ "${failures}" -eq 0 ]]; then
    info "  No committed .env files with secrets"
  fi
}

# =============================================================================
# Check 4: PAT usage pattern (spec requires OAuth)
# =============================================================================
check_pat_usage() {
  info "Checking for PAT usage pattern (spec requires OAuth)..."

  local matches
  matches=$(grep -rn 'HUBSPOT_PAT\|hubspot_pat\|hubspotPat' "${SCAN_PATH}" \
    --include="*.js" --include="*.ts" --include="*.py" \
    2>/dev/null | grep -v 'node_modules' | grep -v 'README' || true)

  if [[ -n "${matches}" ]]; then
    warn "  HUBSPOT_PAT usage found (spec requires OAuth, not PAT):"
    echo "${matches}" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    info "  No PAT usage pattern found (good: should use OAuth)"
  fi
}

# =============================================================================
# Check 5: Password/token logging patterns
# =============================================================================
check_password_logging() {
  info "Checking for password/token logging in code..."

  local matches
  matches=$(grep -rn 'console\.\(log\|info\|warn\|error\).*[Pp]assword\|console\.\(log\|info\|warn\|error\).*[Tt]oken\|console\.\(log\|info\|warn\|error\).*[Ss]ecret\|console\.\(log\|info\|warn\|error\).*[Kk]ey' \
    "${SCAN_PATH}" \
    --include="*.js" --include="*.ts" \
    2>/dev/null | grep -v 'node_modules' | grep -v 'README' | grep -v '// ' || true)

  if [[ -n "${matches}" ]]; then
    warn "  Potential sensitive data in logs:"
    echo "${matches}" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    info "  No sensitive data logging patterns found"
  fi
}

# =============================================================================
# Check 6: Math.random for password generation
# =============================================================================
check_weak_randomness() {
  info "Checking for weak randomness (Math.random) in password generation..."

  local matches
  matches=$(grep -rn 'Math\.random' "${SCAN_PATH}" \
    --include="*.js" --include="*.ts" \
    2>/dev/null | grep -v 'node_modules' || true)

  if [[ -n "${matches}" ]]; then
    warn "  Math.random() usage (should use crypto.randomBytes for passwords):"
    echo "${matches}" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    info "  No Math.random() usage found"
  fi
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Scanning HubSpot webhook codebase for security issues..."
  info "Scan path: ${SCAN_PATH}"
  echo

  if [[ ! -d "${SCAN_PATH}" ]]; then
    error "Scan path not found: ${SCAN_PATH}"
    exit 1
  fi

  check_hardcoded_pats
  echo
  check_sendgrid_keys
  echo
  check_committed_env_files
  echo
  check_pat_usage
  echo
  check_password_logging
  echo
  check_weak_randomness

  echo
  if [[ "${failures}" -eq 0 ]]; then
    info "All ${failures} security checks passed"
    exit 0
  else
    error "${failures} security issue(s) found"
    exit 1
  fi
}

main "$@"
