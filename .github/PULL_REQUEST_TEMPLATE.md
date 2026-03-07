## What changed

<!-- Brief description of the changes -->

## Why

<!-- Motivation, context, link to issue/spec -->

## Checklist

- [ ] Specs updated (if applicable)
- [ ] Tests added or updated
- [ ] No secrets hardcoded
- [ ] CI passes
- [ ] ADR impact output reviewed (`scripts/qa/resolve_adr_impact.py --diff-range <base>...<head>`) and required ADR bundle links included below

## Handoff Guardrails (Required)

- [ ] I ran `./scripts/infra/check-pr-handoff-discipline.sh` and it passed
- [ ] `git status --porcelain` is empty in my source worktree before task switch
- [ ] `git stash list` has no feature work parked
- [ ] If scope was deferred, I linked a follow-up issue/PR in this description

## For infrastructure changes

- [ ] Rollout plan documented
- [ ] Rollback steps identified
- [ ] `apply-patches.sh` re-run (if Tutor config changed)

## Verification

<!-- How to verify this works? Steps, commands, or screenshots -->

## ADR Reading Bundle (if ADR-governed paths changed)

<!-- Paste impacted ADR IDs from CI ADR Governance summary and list required read order -->
