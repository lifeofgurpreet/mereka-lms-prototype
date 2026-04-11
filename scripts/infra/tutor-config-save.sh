#!/usr/bin/env bash
# @covers AC-001
# @spec: tutor-configuration_spec.md
# Safe wrapper for 'tutor config save'
# Automatically prepares Tutor build context and verifies configuration
#
# Usage: ./scripts/infra/tutor-config-save.sh [tutor config save args]
#
# Examples:
#   ./scripts/infra/tutor-config-save.sh --set LMS_HOST=academyv2.mereka.io
#   ./scripts/infra/tutor-config-save.sh --unset MYSQL_ROOT_PASSWORD
#   ./scripts/infra/tutor-config-save.sh  # Interactive mode

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source shared config
# shellcheck source=../shared/config.sh
source "$REPO_ROOT/scripts/shared/config.sh"

# Ensure TUTOR_ROOT is set
if [[ -z "${TUTOR_ROOT:-}" ]]; then
  echo -e "${RED}ERROR: TUTOR_ROOT not set${NC}"
  echo ""
  echo "Please set TUTOR_ROOT before running this script:"
  echo "  export TUTOR_ROOT=\"\$(pwd)/tutor_env\""
  echo ""
  exit 1
fi

# Check if Tutor is available
if ! command -v tutor &>/dev/null; then
  echo -e "${RED}ERROR: tutor command not found${NC}"
  echo ""
  echo "Please ensure Tutor is installed and activated:"
  echo "  source .venv/bin/activate"
  echo ""
  exit 1
fi

# Print current configuration
echo -e "${BLUE}=== Tutor Configuration Manager ===${NC}"
echo ""
echo "Repository:  $REPO_ROOT"
echo "Tutor Root:  $TUTOR_ROOT"
echo ""

SYNC_SCRIPT="$REPO_ROOT/scripts/infra/sync-tutor-plugin-mirror.sh"
if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo -e "${RED}ERROR: Tutor plugin sync script not found or not executable${NC}"
  echo "  Expected: $SYNC_SCRIPT"
  echo ""
  exit 1
fi

echo -e "${BLUE}Step 0: Syncing Tutor plugin mirror${NC}"
"$SYNC_SCRIPT"
echo ""

if tutor plugins disable mfe_oauth_fix >/dev/null 2>&1; then
  echo -e "${YELLOW}Retired standalone Tutor plugin mfe_oauth_fix was enabled and has been disabled${NC}"
  echo ""
fi

# Backup config if it exists
if [[ -f "$TUTOR_ROOT/config.yml" ]]; then
  BACKUP_FILE="$TUTOR_ROOT/config.yml.backup.$(date +%Y%m%d_%H%M%S)"
  echo -e "${YELLOW}Backing up existing config...${NC}"
  cp "$TUTOR_ROOT/config.yml" "$BACKUP_FILE"
  echo "  → $BACKUP_FILE"
  echo ""
fi

# Run tutor config save
echo -e "${BLUE}Step 1: Running 'tutor config save'${NC}"
echo ""

if [[ $# -eq 0 ]]; then
  echo "No arguments provided - running in interactive mode"
  echo "Press Ctrl+C to cancel"
  echo ""
  sleep 2
fi

# Pass all arguments to tutor config save
if tutor config save "$@"; then
  echo ""
  echo -e "${GREEN}✓ Config saved successfully${NC}"
else
  EXIT_CODE=$?
  echo ""
  echo -e "${RED}✗ Config save failed (exit code: $EXIT_CODE)${NC}"
  echo ""
  if [[ -f "$BACKUP_FILE" ]]; then
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$TUTOR_ROOT/config.yml"
    echo -e "${GREEN}✓ Backup restored${NC}"
  fi
  exit $EXIT_CODE
fi

# Prepare Tutor build context
echo ""
echo -e "${BLUE}Step 2: Preparing Tutor build context${NC}"
echo ""

PREP_SCRIPT="$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh"
if [[ ! -x "$PREP_SCRIPT" ]]; then
  echo -e "${RED}ERROR: Canonical build-context script not found or not executable${NC}"
  echo "  Expected: $PREP_SCRIPT"
  echo ""
  exit 1
fi

if "$PREP_SCRIPT" --target all; then
  echo ""
  echo -e "${GREEN}✓ Tutor build context prepared successfully${NC}"
else
  EXIT_CODE=$?
  echo ""
  echo -e "${RED}✗ Tutor build context preparation failed (exit code: $EXIT_CODE)${NC}"
  echo ""
  if [[ -f "$BACKUP_FILE" ]]; then
    read -rp "Restore backup? [Y/n] " response
    case "$response" in
      [nN][oO]|[nN])
        echo "Backup not restored"
        ;;
      *)
        echo "Restoring backup..."
        cp "$BACKUP_FILE" "$TUTOR_ROOT/config.yml"
        echo -e "${GREEN}✓ Backup restored${NC}"
        ;;
    esac
  fi
  exit $EXIT_CODE
fi

# Verify configuration
echo ""
echo -e "${BLUE}Step 3: Verifying configuration${NC}"
echo ""

VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
if [[ -x "$VERIFY_SCRIPT" ]]; then
  if "$VERIFY_SCRIPT"; then
    echo ""
    echo -e "${GREEN}✓ Verification passed${NC}"
  else
    EXIT_CODE=$?
    echo ""
    echo -e "${RED}✗ Verification failed (exit code: $EXIT_CODE)${NC}"
    echo ""
    echo "Some build-context mutations may not have been applied correctly."
    echo ""
    read -rp "Continue anyway? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY])
        echo -e "${YELLOW}Continuing despite verification failure...${NC}"
        ;;
      *)
        echo -e "${RED}Aborted${NC}"
        exit $EXIT_CODE
        ;;
    esac
  fi
else
  echo -e "${YELLOW}⚠ Verification script not found, skipping verification${NC}"
fi

# Success summary
echo ""
echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  ${BLUE}Local development:${NC}"
echo "    tutor local restart"
echo ""
echo "  ${BLUE}Kubernetes:${NC}"
echo "    tutor k8s restart"
echo ""
echo "  ${BLUE}Build new images (if needed):${NC}"
echo "    tutor images build openedx"
echo "    tutor images build mfe"
echo ""

if [[ -f "$BACKUP_FILE" ]]; then
  echo "Backup preserved at:"
  echo "  $BACKUP_FILE"
  echo ""
fi

exit 0
