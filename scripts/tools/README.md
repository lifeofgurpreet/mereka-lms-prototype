# Tools Scripts

Utility scripts for project tooling and automation.

## Beads Viewer Sync

Scripts for syncing the beads database to the web viewer at `beads.mereka.dev/lms/`.

### sync-beads-viewer.sh

Syncs `.beads/beads.db` to the beads viewer and updates the config.json.

**Usage:**
```bash
./scripts/tools/sync-beads-viewer.sh [--force]
```

**Features:**
- Compares SHA256 hashes to skip unnecessary syncs
- Generates `beads.sqlite3.config.json` with file metadata
- Prints bead statistics summary
- Use `--force` to sync even if hashes match

**Cron Setup:**
```bash
# Add to crontab for auto-sync every 15 minutes:
*/15 * * * * /home/gurpreet/projects/k8s/mereka-lms/scripts/tools/sync-beads-viewer.sh >> /tmp/beads-sync.log 2>&1
```

### beads-post-sync-hook.sh

Wrapper script meant to be called after `br sync` operations.

**Usage:**
```bash
./scripts/tools/beads-post-sync-hook.sh
```

**What it does:**
1. Calls `sync-beads-viewer.sh` to update the viewer
2. Updates bead counts in `/home/projects/mcp_agent_mail/beads-hub/index.html`

**Integration:**
Add to your git workflow or call manually after `br sync` operations.
