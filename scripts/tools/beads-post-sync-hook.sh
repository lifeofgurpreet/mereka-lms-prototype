#!/usr/bin/env bash
set -euo pipefail

# Post-sync hook for beads - updates viewer and hub index
# Usage: ./scripts/tools/beads-post-sync-hook.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${MEREKA_LMS_REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
BEADS_DB="${BEADS_DB:-${REPO_ROOT}/.beads/beads.db}"
HUB_INDEX="${HUB_INDEX:-/home/projects/mcp_agent_mail/beads-hub/index.html}"

echo "🔄 Running beads post-sync hook..."

# 1. Sync to viewer
"${SCRIPT_DIR}/sync-beads-viewer.sh"

# 2. Update hub index.html with current counts
echo ""
echo "📝 Updating hub index..."

# Get current statistics
TOTAL=0
OPEN=0

if command -v br &> /dev/null; then
  STATS_OUTPUT=$(br stats 2>/dev/null || true)
  if [[ -n "$STATS_OUTPUT" ]]; then
    TOTAL=$(echo "$STATS_OUTPUT" | grep "Total Issues:" | awk '{print $3}' || echo "0")
    OPEN=$(echo "$STATS_OUTPUT" | grep "Open:" | awk '{print $2}' || echo "0")
  fi
fi

# Fallback: query database directly
if [[ "$TOTAL" == "0" ]]; then
  if [[ -f "$BEADS_DB" ]]; then
    TOTAL=$(sqlite3 "$BEADS_DB" "SELECT COUNT(*) FROM issues;" 2>/dev/null || echo "0")
    OPEN=$(sqlite3 "$BEADS_DB" "SELECT COUNT(*) FROM issues WHERE status IN ('Open', 'InProgress', 'Blocked');" 2>/dev/null || echo "0")
  fi
fi

# Update hub index.html if we have valid stats
if [[ "$TOTAL" -gt 0 ]] && [[ -f "$HUB_INDEX" ]]; then
  # Create backup
  sudo cp "$HUB_INDEX" "${HUB_INDEX}.bak"

  # Update the line with new counts
  sudo sed -i "s|<li><a href=\"/lms/\">Mereka LMS</a> <code>(.*)</code>|<li><a href=\"/lms/\">Mereka LMS</a> <code>(${TOTAL} beads, ${OPEN} open)</code>|" "$HUB_INDEX"

  # Check if update was successful
  if grep -q "(${TOTAL} beads, ${OPEN} open)" "$HUB_INDEX"; then
    echo "✓ Updated hub index: ${TOTAL} beads (${OPEN} open)"
    sudo rm "${HUB_INDEX}.bak"
  else
    echo "⚠️  Hub index update may have failed, backup saved at ${HUB_INDEX}.bak"
  fi
else
  if [[ "$TOTAL" -eq 0 ]]; then
    echo "⚠️  Could not get bead statistics, skipping hub index update"
  elif [[ ! -f "$HUB_INDEX" ]]; then
    echo "⚠️  Hub index not found at $HUB_INDEX"
  fi
fi

echo ""
echo "✅ Post-sync hook complete!"
