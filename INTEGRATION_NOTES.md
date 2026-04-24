# Integration Notes — faizmereka/mereka-lms-prototype fork

**Base:** `Biji-Biji-Initiative/mereka-lms` (full mirror at commit `139627c7`, branch `main`)
**Fork target:** `faizmereka/mereka-lms-prototype`
**Integration date:** 2026-04-24
**Integrator:** Faiz Fadhillah (via Claude)

## Purpose of this fork

The upstream repo `Biji-Biji-Initiative/mereka-lms` is the IaC / deployment source of truth for the live multi-tenant Open edX at:
- `academyv2.mereka.io` (Mereka Academy)
- `academy.biji-biji.com` (Biji-Biji Academy)
- `skillourfuture.academy.mereka.io` (Skill Our Future)

Faiz forked it into `faizmereka/mereka-lms-prototype` to:
1. Own a parallel codebase under his personal GitHub for faster iteration.
2. Co-locate the design prototype (formerly in its own repo, see `docs/design-reference/mereka-ux-prototype/`) with the backend IaC.
3. Experiment with UX changes without blocking the upstream engineering team.

## What's different from upstream

- **Added** `docs/design-reference/mereka-ux-prototype/` — the single-file HTML prototype that drives the UX roadmap.
- **Added** this `INTEGRATION_NOTES.md`.
- **No other changes** yet — this is a clean mirror as of commit `139627c7` (2026-04-24).

## Recommended workflow for this fork

1. Keep the upstream `Biji-Biji-Initiative/mereka-lms` as a `upstream` git remote:
   ```
   git remote add upstream https://github.com/Biji-Biji-Initiative/mereka-lms.git
   ```
2. Sync upstream regularly to avoid drift:
   ```
   git fetch upstream
   git merge upstream/main  # or rebase
   ```
3. Develop new features on feature branches, open PRs internally for review before merging to `main`.
4. If a feature proves valuable, open a matching PR upstream in `Biji-Biji-Initiative/mereka-lms`.
5. Do NOT deploy this fork's code to `academyv2.mereka.io` — that domain deploys from the upstream repo's GitOps pipeline. Changes here are "proposed", not shipped.

## Risks of maintaining a fork

- **Divergence:** every day this fork doesn't merge upstream, drift accumulates. Budget 30 min/week to sync.
- **Double maintenance:** if both forks ship changes independently, conflict resolution becomes expensive.
- **GitOps split brain:** make sure this fork is not accidentally wired into any deployment pipeline.
- **Hostname configs:** `infrastructure/tutor/multisite-sites*.yml` reference production hostnames. Do not deploy this fork anywhere without changing them.

## First 3 actions after fork

1. Read `CLAUDE.md`, `AGENTS.md`, `README.md`, `TRACKER.md` to understand the upstream team's working context.
2. Review `docs/archive/reports/status/NEXT10_TASKS.md` for active priorities.
3. Decide: does this fork become the new source of truth (retire upstream), or stay a sandbox that occasionally contributes back? Affects everything downstream.
