# Beads Tracker

This repository uses the Rust Beads CLI, `br`, for repo-local issue tracking.
The authoritative tracker source is `.beads/issues.jsonl`.

## Current Repo Rule

Use `br`, not the legacy `bd` CLI.

The tracker currently has documented storage/recovery history. Before non-trivial
tracker mutation, read
`docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`. Read-only commands are
safe for normal planning; bulk rewrites or repair attempts need a dedicated
tracker hygiene session.

## Quick Start

### Essential Commands

```bash
# Create new issues
br create "Add user authentication"

# View all issues
br list

# View issue details
br show <issue-id>

# Update issue status
br update <issue-id> --status in_progress
br update <issue-id> --status done

# Export tracker DB changes to JSONL before committing
br sync --flush-only
git add .beads/issues.jsonl
git commit -m "chore(beads): update tracker"
```

### Safe Operating Mode

Issues in Beads are:
- **Git-native**: stored in `.beads/issues.jsonl` and reviewed like code.
- **CLI-first**: use `br ready`, `br list`, `br show`, and `br search`.
- **Graph-aware**: use dependency commands such as `br dep tree <id>` and
  `br dep cycles`.
- **Explicitly flushed**: `br sync --flush-only` writes DB changes back to
  JSONL; it does not run git commands for you.

Recommended read-only planning commands:

```bash
br ready
br list --json
br show <issue-id>
br dep cycles
```

When using Beads Viewer, use robot mode only:

```bash
bv --robot-next
bv --robot-insights
bv --robot-triage
```

Do not run bare `bv`; it opens an interactive TUI.

## Related Docs

- `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`
- `docs/status/active/CURRENT-OPERATOR-STATE.md`
- `docs/guides/standards/bead-v2-format.md`
