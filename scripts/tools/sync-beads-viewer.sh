#!/usr/bin/env bash
set -euo pipefail

# Copies .beads/beads.db → beads-hub viewer, updates config.json
# Usage: ./scripts/tools/sync-beads-viewer.sh [--force]

BEADS_DB="/home/gurpreet/projects/k8s/mereka-lms/.beads/beads.db"
VIEWER_DIR="/home/projects/mcp_agent_mail/beads-hub/lms"
VIEWER_DB="${VIEWER_DIR}/beads.sqlite3"
VIEWER_CONFIG="${VIEWER_DIR}/beads.sqlite3.config.json"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

# Check if source database exists
if [[ ! -f "$BEADS_DB" ]]; then
  echo "❌ Source database not found: $BEADS_DB"
  exit 1
fi

# Check if viewer directory exists
if [[ ! -d "$VIEWER_DIR" ]]; then
  echo "❌ Viewer directory not found: $VIEWER_DIR"
  exit 1
fi

# Calculate hash of source database
SOURCE_HASH=$(sha256sum "$BEADS_DB" | awk '{print $1}')
SOURCE_SIZE=$(stat -c%s "$BEADS_DB")

# Check if destination exists and compare hashes
if [[ -f "$VIEWER_DB" ]] && [[ "$FORCE" == false ]]; then
  DEST_HASH=$(sha256sum "$VIEWER_DB" | awk '{print $1}')
  if [[ "$SOURCE_HASH" == "$DEST_HASH" ]]; then
    echo "✓ Database already in sync (hash: ${SOURCE_HASH:0:12}...)"
    exit 0
  fi
fi

# Copy the database
echo "📦 Syncing beads database..."
sudo cp "$BEADS_DB" "$VIEWER_DB"
sudo chown gurpreet:gurpreet "$VIEWER_DB"

# Generate config.json
cat > /tmp/beads.config.json <<EOF
{
  "chunked": false,
  "chunk_count": 0,
  "chunk_size": 0,
  "total_size": ${SOURCE_SIZE},
  "hash": "${SOURCE_HASH}"
}
EOF

sudo cp /tmp/beads.config.json "$VIEWER_CONFIG"
sudo chown gurpreet:gurpreet "$VIEWER_CONFIG"
rm /tmp/beads.config.json

# Get bead statistics
TOTAL=0
OPEN=0
CLOSED=0

if command -v br &> /dev/null; then
  # Try to get stats from br command
  STATS_OUTPUT=$(br stats 2>/dev/null || true)
  if [[ -n "$STATS_OUTPUT" ]]; then
    TOTAL=$(echo "$STATS_OUTPUT" | grep "Total Issues:" | awk '{print $3}' || echo "0")
    OPEN=$(echo "$STATS_OUTPUT" | grep -E "^\s+Open:" | awk '{print $2}' || echo "0")
    CLOSED=$(echo "$STATS_OUTPUT" | grep -E "^\s+Closed:" | awk '{print $2}' || echo "0")
  fi
fi

# Fallback: query database directly if br stats didn't work
if [[ "$TOTAL" == "0" ]]; then
  TOTAL=$(sqlite3 "$VIEWER_DB" "SELECT COUNT(*) FROM issues;" 2>/dev/null || echo "0")
  OPEN=$(sqlite3 "$VIEWER_DB" "SELECT COUNT(*) FROM issues WHERE status IN ('Open', 'InProgress', 'Blocked');" 2>/dev/null || echo "0")
  CLOSED=$(sqlite3 "$VIEWER_DB" "SELECT COUNT(*) FROM issues WHERE status = 'Closed';" 2>/dev/null || echo "0")
fi

# Print summary
echo "✓ Synced: ${TOTAL} beads (${OPEN} open, ${CLOSED} closed) → beads.mereka.dev/lms/"
echo "  Hash: ${SOURCE_HASH:0:12}..."
echo "  Size: $(numfmt --to=iec-i --suffix=B ${SOURCE_SIZE} 2>/dev/null || echo "${SOURCE_SIZE} bytes")"

# Print cron setup instructions
cat <<'EOF'

💡 To auto-sync every 15 minutes, add to crontab:
   */15 * * * * /home/gurpreet/projects/k8s/mereka-lms/scripts/tools/sync-beads-viewer.sh >> /tmp/beads-sync.log 2>&1
EOF
