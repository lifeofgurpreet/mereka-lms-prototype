# Merge-First Deployment Protocol

**Status**: Active
**Last Updated**: 2026-02-18

## Protocol

All changes MUST be merged to `main` via Pull Request before deployment to production. No direct `kubectl apply`, `kubectl patch`, or ArgoCD manual sync from feature branches.

### Why

1. **ArgoCD reverts manual patches**: The GitOps controller syncs from the `bbi-infrastructure` repo. Any `kubectl patch` or direct edit gets overwritten on next sync cycle.
2. **Worktree divergence**: Multiple agents working on separate worktrees/branches can produce conflicting changes. Merging to main first ensures a single source of truth.
3. **Audit trail**: PRs provide code review, CI checks, and a permanent record of what changed and why.

### Workflow

```
1. Create feature branch from main
2. Implement changes
3. Run verification: bash scripts/qa/<relevant-verify-script>.sh
4. Push branch, create PR
5. Merge PR to main (squash or merge commit)
6. ArgoCD auto-syncs from main (bbi-infrastructure watches main)
7. Close bead: br close <bead-id>
8. Sync beads: br sync --flush-only && git add .beads/ && git commit && git push
```

### Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|-------------|-------------|------------------|
| `kubectl patch` on live cluster | ArgoCD reverts within sync interval | Commit to `bbi-infrastructure`, let ArgoCD apply |
| Deploy from feature branch | Other agents may overwrite | Merge to main first, deploy from main |
| Cherry-pick to main without PR | No CI, no review trail | Create PR even for single-commit changes |
| Direct `tutor config save` on cluster | Loses apply-patches.sh customizations | Use `tutor-config-save.sh` wrapper locally, commit result |
| Amend published commits | Destroys history, breaks other agents | Create new commit instead |

### Multi-Agent Coordination

When multiple agents work in parallel:

1. **Single canonical worktree**: All agents use `/home/gurpreet/projects/k8s/mereka-lms` on `main`
2. **Feature branches**: Create short-lived branches (`feat/<bead-id>-<slug>`)
3. **File reservations**: Use Agent Mail `file_reservation_paths` before editing shared files
4. **Sequential merges**: Only one PR merged at a time to avoid conflicts
5. **Checkpoint format**: `CHECKPOINT: path=<pwd> | branch=<branch> | HEAD=<sha> | step=<next>`

### Stale Branch Policy

- Feature branches MUST be deleted after PR merge (use `--delete-branch` flag)
- Local branches merged to main SHOULD be pruned weekly
- Worktrees not updated in 7+ days SHOULD be removed
- Run `scripts/infra/cleanup-stale-branches.sh` to automate

## Related

- `docs/operations/BRANDING_RELEASE_RUNBOOK.md` — Production rollout steps
- `scripts/qa/verify-gitops-drift.sh` — Detect drift between source and GitOps overlay
- `AGENTS.md` — Repository agent guidelines
