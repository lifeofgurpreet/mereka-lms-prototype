# Operator Preflight

## Why

The VPS `ssh mereka` carries three repo checkouts that agents and humans use as canonical ground truth:

- `/home/gurpreet/projects/k8s/mereka-lms`
- `/home/gurpreet/projects/k8s/bbi-infrastructure`
- `/home/gurpreet/projects/bbi-infrastructure`

All three drift. Feature branches stick around. `local main` falls behind `origin/main`. Untracked artifacts accumulate. **Every operator decision made without checking these first is making decisions against stale state.**

## Standing Rule (introduced 2026-04-18)

> Every `ssh mereka` session starts with `bin/preflight`. No exceptions.

## Usage

```bash
# default: runs against the three canonical VPS checkouts
bin/preflight

# custom paths
bin/preflight /path/to/repo-a /path/to/repo-b

# machine-readable (for agents and dashboards)
bin/preflight --json
```

## Output Contract

One line per repo, containing:
- `branch` — currently checked-out branch name, or `detached`
- `head=<12-char SHA>` — current HEAD of the checkout
- `origin/main=<12-char SHA>` — fetched tip of origin/main
- `local/main=<12-char SHA>` — local main branch (may differ from HEAD when on a feature branch)
- `dirty=<N>` — count of uncommitted/untracked files
- `ahead/behind=<A>/<B>` — commits origin/main is ahead/behind the current HEAD
- `status` — one of:
  - `CLEAN` — head == origin/main, dirty == 0, local/main == origin/main
  - `DRIFTED` — head != origin/main (on a feature branch or stale)
  - `+DIRTY` — uncommitted changes present
  - `+STALE-MAIN` — local main is behind origin/main (needs `git pull`)
  - Status flags are additive (e.g. `DRIFTED+DIRTY+STALE-MAIN`)

Exit code: `0` if all repos CLEAN, `2` if any drift detected.

## Example Output (2026-04-18T05:32Z)

```
/home/gurpreet/projects/k8s/mereka-lms             branch=docs/final-deliverables-rc07-closed-20260418  head=8ad25feb30bf origin/main=9211c5479a9b local/main=330fd0f98d08 dirty=10 ahead/behind=0/1 → DRIFTED+DIRTY+STALE-MAIN
/home/gurpreet/projects/k8s/bbi-infrastructure     branch=main                                          head=41d3d4149e96 origin/main=21322557f159 local/main=41d3d4149e96 dirty=402 ahead/behind=18/0 → DRIFTED+DIRTY+STALE-MAIN
/home/gurpreet/projects/bbi-infrastructure         branch=main                                          head=2b94a4c5726b origin/main=21322557f159 local/main=2b94a4c5726b dirty=1 ahead/behind=25/0 → DRIFTED+DIRTY+STALE-MAIN
```

All three repos DRIFTED+DIRTY+STALE-MAIN at preflight time. **Operators who ignored this ended up reasoning against stale state.**

## Canonical Checkout Policy (recommended)

When working on the VPS:

1. **Do not edit the primary checkouts** (`/home/gurpreet/projects/k8s/mereka-lms`, etc.). Treat them as read-only canonical mirrors.
2. **For any edit, create a clean worktree** off `origin/main`:
   ```bash
   cd /home/gurpreet/projects/k8s/mereka-lms
   git fetch origin main
   git worktree add -f /home/gurpreet/worktrees/mereka-lms-main origin/main
   cd /home/gurpreet/worktrees/mereka-lms-main
   git checkout -b <your-branch>
   ```
3. **Never leave a feature branch checked out in the primary mirror.** If you did, reset before leaving the session:
   ```bash
   cd /home/gurpreet/projects/k8s/mereka-lms
   git checkout main
   git pull --ff-only origin main
   ```

The primary checkouts are now agreed to be read-only canonical mirrors, worktrees are the edit surface. `bin/preflight` enforces this by making drift visible.

## When Preflight Shows Drift

Read the drift line, then decide:
- `DRIFTED+STALE-MAIN` alone → run `git checkout main && git pull --ff-only` in the primary checkout
- `DRIFTED+DIRTY` → either commit and push on the feature branch, or stash and reset
- `STALE-MAIN` alone → `git fetch origin && git checkout main && git pull --ff-only`

Never take a remediation action on the primary checkout without first confirming the `bin/preflight` output matches your expectation afterward.

## Automation Hook

To enforce preflight at shell-startup on the VPS:

```bash
# in ~/.zshrc or ~/.bashrc
if command -v preflight &>/dev/null; then
  preflight 2>&1 | head -3
fi
```

This prints one line per repo on login. If any DRIFTED, the operator sees it immediately.

## Related

- Bead `mereka-lms-p74m` (P1): canonical checkout policy + preflight script
- Tracker: `docs/status/active/OPENEDX_NEXT_PHASE_PLAN_2026-04-18.md` (Phase 1)
