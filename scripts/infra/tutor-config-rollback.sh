#!/usr/bin/env bash
# @covers AC-TCR-005, AC-TCR-012
# @spec: tutor-configuration-resilience_spec.md
# Restore Tutor config.yml from a timestamped backup created by tutor-config-save.sh,
# then rerun the governed render/prepare wrapper to bring the environment into a
# consistent state.
#
# Usage:
#   ./scripts/infra/tutor-config-rollback.sh              # List available backups
#   ./scripts/infra/tutor-config-rollback.sh <timestamp>   # Restore specific backup
#   ./scripts/infra/tutor-config-rollback.sh latest         # Restore most recent backup
#
# Examples:
#   ./scripts/infra/tutor-config-rollback.sh 20260210_143022
#   ./scripts/infra/tutor-config-rollback.sh latest

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../shared/config.sh
source "$REPO_ROOT/scripts/shared/config.sh"

TUTOR_ENV="${TUTOR_ROOT:-${REPO_ROOT}/tutor_env}"
CONFIG_FILE="$TUTOR_ENV/config.yml"

usage() {
  echo "Usage: $(basename "$0") [<timestamp>|latest]"
  echo ""
  echo "  No arguments   List available backups"
  echo "  <timestamp>     Restore backup matching timestamp (e.g. 20260210_143022)"
  echo "  latest          Restore the most recent backup"
  echo ""
  echo "Backups are created by tutor-config-save.sh at:"
  echo "  $TUTOR_ENV/config.yml.backup.<timestamp>"
}

list_backups() {
  local backups
  backups=$(compgen -G "$TUTOR_ENV/config.yml.backup.*" 2>/dev/null | sort -r || true)

  if [[ -z "$backups" ]]; then
    echo -e "${YELLOW}No backups found in $TUTOR_ENV${NC}"
    return 1
  fi

  echo -e "${BLUE}Available backups (newest first):${NC}"
  echo ""
  while IFS= read -r backup; do
    local ts
    ts="${backup##*.backup.}"
    local size
    size=$(stat --printf="%s" "$backup" 2>/dev/null || stat -f%z "$backup" 2>/dev/null || echo "?")
    echo "  $ts  ($(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B"))"
  done <<< "$backups"
  echo ""
  echo "Restore with: $(basename "$0") <timestamp>"
}

resolve_backup() {
  local selector="$1"

  if [[ "$selector" == "latest" ]]; then
    local latest
    latest=$(compgen -G "$TUTOR_ENV/config.yml.backup.*" 2>/dev/null | sort -r | head -1 || true)
    if [[ -z "$latest" ]]; then
      echo -e "${RED}ERROR: No backups found${NC}" >&2
      exit 1
    fi
    echo "$latest"
    return
  fi

  local candidate="$TUTOR_ENV/config.yml.backup.$selector"
  if [[ -f "$candidate" ]]; then
    echo "$candidate"
    return
  fi

  # Try partial match
  local matches
  matches=$(compgen -G "$TUTOR_ENV/config.yml.backup.${selector}*" 2>/dev/null || true)
  local count
  count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    echo -e "${RED}ERROR: No backup matching '$selector'${NC}" >&2
    exit 1
  elif [[ "$count" -gt 1 ]]; then
    echo -e "${RED}ERROR: Multiple backups match '$selector':${NC}" >&2
    echo "$matches" | while read -r m; do echo "  ${m##*.backup.}"; done >&2
    exit 1
  fi

  echo "$matches"
}

restore_backup() {
  local backup_file="$1"
  local ts="${backup_file##*.backup.}"

  echo -e "${BLUE}=== Tutor Config Rollback ===${NC}"
  echo ""
  echo "Backup:    $backup_file"
  echo "Timestamp: $ts"
  echo "Target:    $CONFIG_FILE"
  echo ""

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}No current config.yml found — restoring from backup${NC}"
  fi

  cp "$backup_file" "$CONFIG_FILE"
  echo -e "${GREEN}✓ config.yml restored from backup ($ts)${NC}"
  echo ""

  # Regenerate rendered templates, prepare build context, and verify through the
  # same governed wrapper used by normal Tutor config changes.
  echo -e "${BLUE}Step 1: Regenerating templates through governed Tutor wrapper...${NC}"
  CONFIG_SAVE_SCRIPT="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
  if [[ ! -x "$CONFIG_SAVE_SCRIPT" ]]; then
    echo -e "${RED}ERROR: tutor-config-save.sh not found or not executable${NC}" >&2
    echo "  Expected: $CONFIG_SAVE_SCRIPT" >&2
    exit 1
  fi

  if TUTOR_ROOT="$TUTOR_ENV" "$CONFIG_SAVE_SCRIPT"; then
    echo -e "${GREEN}✓ Restored config rendered, prepared, and verified${NC}"
  else
    echo -e "${RED}✗ Governed Tutor config wrapper failed — check output above${NC}" >&2
    exit 1
  fi
  echo ""

  echo -e "${GREEN}=== Rollback Complete ===${NC}"
  echo ""
  echo "Next steps:"
  echo "  make tutor-restart     # Apply restored config locally"
  echo "  release-object GitOps promotion owns Kubernetes rollout"
}

# --- Main ---

if [[ $# -eq 0 ]]; then
  list_backups
  exit 0
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

BACKUP_FILE=$(resolve_backup "$1")
restore_backup "$BACKUP_FILE"
