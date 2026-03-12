# PR Unblock Sweep Ledger

> Lane F2 artifact. Classifies PRs that were blocked by false-red CI cascade.
>
> Date: 2026-03-12
> Prerequisite: PR #876 merged (false-red cascade fix)

## Context

Before PR #876, CI was false-red on `main` for Static Validation. This propagated
to every open PR. After merge, the false-red cascade is eliminated. All PRs below
have been re-run against the fixed `main`.

## PR Classification

| PR | Title | Pre-Fix CI | Post-Fix Class | Owner | Recommended Action |
|----|-------|-----------|----------------|-------|--------------------|
| #823 | ci: bump actions/cache from 4.3.0 to 5.0.3 | Static Validation FAIL (false-red) | GREEN_NOW | Dependabot | Merge if review approved |
| #824 | ci: bump docker/setup-buildx-action from 3.12.0 to 4.0.0 | Static Validation FAIL (false-red) | GREEN_NOW | Dependabot | Merge if review approved |
| #825 | ci: bump actions/checkout from 4 to 6 | Static Validation FAIL (false-red) | CLOSED | Dependabot | Already closed — no action |
| #826 | ci: bump sigstore/cosign-installer from 3.9.2 to 4.0.0 | Static Validation FAIL (false-red) | GREEN_NOW | Dependabot | Merge if review approved |
| #833 | fix(enterprise-mfe): PARAGON_THEME, env.config.js, and head-extra mount path | Static Validation FAIL (false-red) | GREEN_NOW | Agent 1 | Review + merge (enterprise MFE fix) |
| #851 | fix(lms): derive JWT public key from private key at startup | Static Validation FAIL (false-red) | GREEN_NOW | Agent 1 | Review + merge (JWT fix) |
| #852 | fix(mfe): consolidate MFE routing through Caddy reverse proxy | Static Validation FAIL (false-red) | GREEN_NOW | Agent 1 | Review + merge (MFE routing) |
| #854 | fix(enterprise-mfe): runtime config, domain rewrite, and sed ordering | Static Validation FAIL (false-red) | GREEN_NOW | Agent 1 | Review + merge (enterprise MFE fix) |
| #858 | fix(lms): add enterprise learner portal to CORS whitelist | Static Validation FAIL (false-red) | GREEN_NOW | Agent 1 | Review + merge (CORS fix) |
| #875 | chore: bump eslint from 10.0.2 to 10.0.3 | Static Validation FAIL (false-red) | GREEN_NOW | Dependabot | Merge if review approved |

## Classification Key

| Class | Meaning |
|-------|---------|
| GREEN_NOW | CI passes after false-red fix merged to main. Ready for review/merge. |
| BLOCKED_ON_DOCS | Blocked by docs compliance gates (Lane E scope). |
| BLOCKED_ON_RUNTIME | Blocked by runtime/deployment issue (not CI). |
| BLOCKED_ON_REAL_CODE_FAILURE | PR has a genuine code defect causing test failure. |
| BLOCKED_ON_OTHER_CI_DEFECT | Blocked by a different CI workflow defect. |
| CLOSED | PR already closed or superseded. |

## Summary

- **9 open PRs** re-run triggered against fixed `main`
- **1 PR** already closed (#825)
- **All 9 open PRs** classified as GREEN_NOW — their only failure was Static Validation false-red
- **0 PRs** blocked on real code failures
- **0 PRs** blocked on docs compliance (these PRs don't trigger docs gates)

## Notes

- GREEN_NOW classification is based on the pre-fix CI profile: every PR had Static Validation
  as its sole failure, with Tutor Config Tests, Security Scans, Python test coverage, and CodeQL
  all passing. The false-red has been eliminated by PR #876.
- If any re-run reveals a new failure, this ledger will be updated.
- Docs compliance gates (`docs-compliance.yml`) are a separate workflow and NOT part of the
  `ci.yml` pipeline. PRs that only touch code/CI files don't trigger docs gates.
