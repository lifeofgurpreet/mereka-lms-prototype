# Next Agent Handoff (2026-03-01)

## Canonical Baseline

- Commit: `9ed0f591e0cfafcd7643c82693b3b0844c45612e`
- Primary branch: `build/tenantfix-20260228-r6`
- Start-here branch: `start/next-implementor-2026-03-01`
- Backup branch: `backup/handoff-fc2ce2b5`
- Ready tag (current canonical): `handoff/2026-03-01-ready-next-agent` -> `9ed0f591e0cfafcd7643c82693b3b0844c45612e`
- Historical tag (earlier snapshot): `handoff/2026-03-01-clean-baseline-fc2ce2b5b3e7` -> `fc2ce2b5...`

Primary/start/backup branches plus `handoff/2026-03-01-ready-next-agent` intentionally point to the same commit; the historical snapshot tag remains on the earlier baseline.

## Safety State Completed

- Main worktree is clean and synced.
- Stale auxiliary worktree was removed.
- Local Beads DB corruption was recovered and `br sync --flush-only` is operational again.
- `.beads/issues.jsonl` has been resynced from the recovered DB.

## Start Commands (Next Developer)

```bash
git fetch --all --prune
git switch start/next-implementor-2026-03-01
git pull --ff-only
git status --short --branch
git worktree list
```

Expected result:

- Branch is up to date with origin.
- Working tree is clean.
- Only the main worktree is present.

## Ref Integrity Check

```bash
BASE=9ed0f591e0cfafcd7643c82693b3b0844c45612e
git rev-parse build/tenantfix-20260228-r6
git rev-parse start/next-implementor-2026-03-01
git rev-parse backup/handoff-fc2ce2b5
git rev-list -n1 handoff/2026-03-01-ready-next-agent
git rev-list -n1 handoff/2026-03-01-clean-baseline-fc2ce2b5b3e7
```

The first three commands should resolve to `$BASE`.

## Notes

- If Beads sync fails again, first run `sqlite3 .beads/beads.db 'PRAGMA quick_check;'` before any changes.
- Use the start-here branch for new work; keep backup/tag untouched.

---

## Addendum (2026-03-02 Stabilization)

### Updated Canonical Start Point

- `main` and `start/next-implementor-2026-03-01` are aligned at: `6e6bcb6d`.
- All updates in this addendum were executed in `mereka-lms` repo only (no GitOps repo mutations).

### What Landed Since 2026-03-01 Baseline

- Auth-surface contract stabilization for runtime checks:
  - branded notes banner accepted
  - forum non-prod `/healthz` fallback accepted while prod still requires `/heartbeat=200`
- Auth-surface diagnostics hardening:
  - failures now emit `diag{...}` metadata (status, location, content-type, request IDs when available, body snippet)
- Closure evidence refreshes:
  - latest screenshots, DOM/a11y/certificate reruns, CI ceremony contract reruns
  - matrix + branding plan updated with current artifacts and commit trace
- Troubleshooting runbook expanded with dev `credentials` 500 failure mode (`ZoneInfoNotFoundError` + missing `tzdata` signal).

### Remaining Blocker (Current)

- Dev runtime only: `credentials.academyv2.mereka.dev` login endpoints (`/login`, `/login/edx-oauth2`, `/admin/login`) return `500`.
- Prod control lane for same surfaces is healthy (`302` redirects).
- Latest evidence logs:
  - `var/qa/auth-surfaces-dev-20260302T064809Z.log`
  - `var/qa/auth-surfaces-prod-20260302T064809Z.log`

### Start Commands (Updated)

```bash
git fetch --all --prune
git switch start/next-implementor-2026-03-01
git pull --ff-only
git rev-parse --short HEAD
git status --short --branch
```

Expected HEAD: `6e6bcb6d`.
