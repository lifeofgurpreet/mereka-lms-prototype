# PR Unblock Sweep Ledger

> Lane F2 artifact. Classifies PRs that were blocked by false-red CI cascade.
>
> Date: 2026-03-12 (updated after branch merge-forward)
> Prerequisite: PR #876 merged (false-red cascade fix)

## Context

Before PR #876, CI was false-red on `main` for Static Validation. This propagated
to every open PR. After merge, PR branches needed to merge main to pick up the
`lsb_release` stub and other fixes in `.github/actions/setup-python-env/`.

All PR branches have been updated via `update-branch` API. Two PRs (#833, #854)
have merge conflicts requiring manual resolution by their owner (Agent 1).

## PR Classification

| PR | Title | Pre-Fix CI | Post-Fix Class | Branch Updated | Owner | Recommended Action |
|----|-------|-----------|----------------|----------------|-------|--------------------|
| #823 | ci: bump actions/cache from 4.3.0 to 5.0.3 | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Dependabot | Merge when CI passes |
| #824 | ci: bump docker/setup-buildx-action from 3.12.0 to 4.0.0 | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Dependabot | Merge when CI passes |
| #825 | ci: bump actions/checkout from 4 to 6 | Static Validation FAIL (false-red) | CLOSED | N/A | Dependabot | Already closed |
| #826 | ci: bump sigstore/cosign-installer from 3.9.2 to 4.0.0 | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Dependabot | Merge when CI passes |
| #833 | fix(enterprise-mfe): PARAGON_THEME, env.config.js, and head-extra mount path | Static Validation FAIL (false-red) | BLOCKED_ON_MERGE_CONFLICT | No (conflict) | Agent 1 | Resolve merge conflict with main, then re-run CI |
| #851 | fix(lms): derive JWT public key from private key at startup | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Agent 1 | Merge when CI passes |
| #852 | fix(mfe): consolidate MFE routing through Caddy reverse proxy | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Agent 1 | Merge when CI passes |
| #854 | fix(enterprise-mfe): runtime config, domain rewrite, and sed ordering | Static Validation FAIL (false-red) | BLOCKED_ON_MERGE_CONFLICT | No (conflict) | Agent 1 | Resolve merge conflict with main, then re-run CI |
| #858 | fix(lms): add enterprise learner portal to CORS whitelist | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Agent 1 | Merge when CI passes |
| #875 | chore: bump eslint from 10.0.2 to 10.0.3 | Static Validation FAIL (false-red) | GREEN_NOW | Yes | Dependabot | Merge when CI passes |

## Classification Key

| Class | Meaning |
|-------|---------|
| GREEN_NOW | Branch updated with main. CI expected to pass on re-run. Ready for review/merge. |
| BLOCKED_ON_MERGE_CONFLICT | Branch conflicts with main. Owner must resolve before CI can run. |
| BLOCKED_ON_DOCS | Blocked by docs compliance gates (Lane E scope). |
| BLOCKED_ON_RUNTIME | Blocked by runtime/deployment issue (not CI). |
| BLOCKED_ON_REAL_CODE_FAILURE | PR has a genuine code defect causing test failure. |
| BLOCKED_ON_OTHER_CI_DEFECT | Blocked by a different CI workflow defect. |
| CLOSED | PR already closed or superseded. |

## Summary

- **9 open PRs** inspected
- **1 PR** already closed (#825)
- **7 PRs** branch-updated with main, CI re-running → GREEN_NOW
- **2 PRs** have merge conflicts (#833, #854) — both are Agent 1 enterprise MFE PRs
- **0 PRs** blocked on real code failures
- **0 PRs** blocked on docs compliance

## Why Re-Run Alone Wasn't Enough

The CI false-red fix (PR #876) added a `lsb_release` stub to `.github/actions/setup-python-env/`.
GitHub Actions composite actions are read from the **PR branch**, not from `main`. So PRs
created before #876 merged don't have the stub. Simply re-running CI without merging main
into the PR branch causes `Set up Python environment` to fail.

Fix: `gh api pulls/{id}/update-branch` merges main into the PR branch, giving it the stub.

## Additional CI Defect Found

During this sweep, a new RUNNER_CAPABILITY_DEFECT was discovered:
- **Markdown linting** step runs `npm install -g markdownlint-cli` which fails with EACCES
  on ARC runners (no write access to `/usr/lib/node_modules/`)
- Fixed in PR #880: install locally + use `npx` instead of global install
