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

is_noninteractive() {
  [[ "${CI:-}" == "true" || ! -t 0 ]]
}

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source shared config
# shellcheck source=../shared/config.sh
source "$REPO_ROOT/scripts/shared/config.sh"

TUTOR_ENV_HELPER="$REPO_ROOT/infrastructure/tutor/tutor-env.sh"
if [[ -z "${TUTOR_ROOT:-}" || ! $(command -v tutor >/dev/null 2>&1; echo $?) -eq 0 ]]; then
  if [[ -f "$TUTOR_ENV_HELPER" ]]; then
    # shellcheck source=../../infrastructure/tutor/tutor-env.sh
    source "$TUTOR_ENV_HELPER"
  fi
fi

# Ensure TUTOR_ROOT is set
if [[ -z "${TUTOR_ROOT:-}" ]]; then
  echo -e "${RED}ERROR: TUTOR_ROOT not set${NC}"
  echo ""
  echo "Expected repo-local Tutor root:"
  echo "  $REPO_ROOT/tutor_env"
  echo ""
  echo "Fallback helper: $TUTOR_ENV_HELPER"
  echo ""
  exit 1
fi

# Check if Tutor is available
if ! command -v tutor &>/dev/null; then
  echo -e "${RED}ERROR: tutor command not found${NC}"
  echo ""
  echo "Expected repo-local Tutor virtualenv:"
  echo "  $REPO_ROOT/.venv"
  echo ""
  echo "Fallback helper: $TUTOR_ENV_HELPER"
  echo ""
  exit 1
fi

# Print current configuration
echo -e "${BLUE}=== Tutor Configuration Manager ===${NC}"
echo ""
echo "Repository:  $REPO_ROOT"
echo "Tutor Root:  $TUTOR_ROOT"
echo ""

PLUGIN_DIR="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}}"
export TUTOR_PLUGINS_ROOT="$PLUGIN_DIR"
export TUTOR_PLUGINS_DIR="$PLUGIN_DIR"

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

for retired_plugin in mfe_oauth_fix indigo; do
  if tutor plugins disable "$retired_plugin" >/dev/null 2>&1; then
    echo -e "${YELLOW}Retired Tutor plugin ${retired_plugin} was enabled and has been disabled${NC}"
    echo ""
  fi
done

for plugin in mereka_lms mereka_lms_mfe_slots; do
  if tutor plugins enable "$plugin" >/dev/null 2>&1; then
    echo -e "${GREEN}Canonical Tutor plugin enabled: ${plugin}${NC}"
  else
    echo -e "${RED}ERROR: Failed to enable canonical Tutor plugin: ${plugin}${NC}" >&2
    exit 1
  fi
done
echo ""

# Backup config if it exists
BACKUP_FILE=""
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
  if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
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
  if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    if is_noninteractive; then
      echo "Restoring backup automatically (non-interactive mode)..."
      cp "$BACKUP_FILE" "$TUTOR_ROOT/config.yml"
      echo -e "${GREEN}✓ Backup restored${NC}"
    else
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
    if is_noninteractive; then
      echo -e "${RED}Aborted in non-interactive mode${NC}"
      exit $EXIT_CODE
    else
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
echo "  ${BLUE}Fast local image refresh:${NC}"
echo "    ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast"
echo "    ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
echo ""
echo "  ${BLUE}Strict Open edX proof rebuild:${NC}"
echo "    BENCHMARK_CLASS=proof-class ./scripts/bench/measure-openedx-build.sh \"$REPO_ROOT\" openedx-proof-noneditable"
echo ""

if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
  echo "Backup preserved at:"
  echo "  $BACKUP_FILE"
  echo ""
fi

exit 0
