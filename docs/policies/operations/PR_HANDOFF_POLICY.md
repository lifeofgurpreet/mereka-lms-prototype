# PR Handoff Policy

This policy prevents local-only implementation drift where improvements exist in a worktree but are not shipped in a branch or PR.

## Mandatory Rules

1. **No dirty handoff**
   - Before switching tasks or handing work to another implementor, `git status --porcelain` MUST be empty.

2. **No hidden feature stash**
   - `git stash list` MUST NOT contain feature work. Use branches and PRs instead of parked stash entries.

3. **Stay synced with `main`**
   - Feature branches SHOULD be rebased/synced on `origin/main` after merges land.
   - Post-merge baseline:
     - `git checkout main`
     - `git pull --rebase origin main`

4. **No unpushed feature commits at handoff**
   - If work exists locally, it must be pushed to a branch and represented by a PR (or explicitly linked follow-up issue/PR).

## Enforced Command

Run the guard before handoff:

```bash
./scripts/infra/check-pr-handoff-discipline.sh
```

Optional flags:

```bash
./scripts/infra/check-pr-handoff-discipline.sh --max-behind 0
./scripts/infra/check-pr-handoff-discipline.sh --allow-stash
```

## PR Contract

The repository PR template includes a required **Handoff Guardrails** checklist. Authors must complete it before requesting review.
