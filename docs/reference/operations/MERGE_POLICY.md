---
title: Merge Policy
type: reference
owner: platform-release
status: active
---

# Merge Policy

Authoritative source for how PRs land on `main` across mereka-lms. Cross-links
to `config/branch-protection-contract.yaml` (machine-checkable live vs target
settings) and `scripts/qa/verify-branch-protection-contract.sh`.

## Rationale

The repo historically ran with classic branch protection in **strict mode**:

```
required_status_checks:
  strict: true            # PR must be up-to-date with main before merge
```

Combined with `allow_auto_merge: true` and no merge-queue, this forced the
operator pattern:

1. Arm PR with `gh pr merge --auto`
2. Unrelated PR lands on main
3. All other open PRs go `BEHIND`
4. Auto-merge does NOT rebase — it just waits
5. Operator calls `gh api -X PUT /.../pulls/N/update-branch` on every open PR
6. Each rebase reruns the full CI footprint
7. Repeat from step 2 on the next landing

The pattern wastes CI budget, creates rebase-storm churn, and is not
self-healing. On 2026-04-20 the 10-PR cascade (`#1918 … #1934`) sat BEHIND
for hours because each merge dumped the queue back to BEHIND.

## Target operating model — staged rollout

Rollout is staged. Each stage is reversible; later stages only open after
the prior stage is proven in production.

### Stage 1 — Loose mode (strict=false)

**Status**: **ACTIVE since 2026-04-20**. Flip executed live via
`PUT /repos/Biji-Biji-Initiative/mereka-lms/branches/main/protection`
after PR #1935 opened; rollback snapshot at
`/tmp/protection-rollback/mereka-lms-main-pre-20260420T111643Z.json` on
the operator host.

```
required_status_checks:
  strict: false
```

Effect:
- PRs can merge when required checks pass, regardless of whether the branch
  is currently behind `main`.
- `--auto` merge fires as soon as checks go green — no rebase needed unless
  the PR itself has merge conflicts.
- Stops the rebase-storm pattern immediately.

Tradeoff:
- Integration drift can slip in. A PR that passes checks against a stale
  base could merge and break `main` if two in-flight PRs conflict
  semantically but not textually.
- Acceptable on this repo because ≥90% of churn is docs / YAML / isolated
  script work with low cross-file risk. Monitored via `main` CI red rate.

This is the **current** target.

### Stage 2 — Merge queue canary

**Status**: not yet activated. Blocked on Stage 1 producing 2 weeks of
stable `main` CI (red rate ≤ 1 run/week).

Concrete moves:

1. Enable merge queue on `main` via repository ruleset (classic branch
   protection cannot configure merge queue — requires migration to
   rulesets).
2. Start with one required check on the merge queue rule (not all 7).
3. Queue a no-op PR (docs-only). Confirm a `merge_group` event fires
   and the workflow run succeeds. Today there are zero historical
   `merge_group` runs, so this is an unvalidated path.
4. Expand to all 7 required checks on the merge-queue rule.

Stage 2 closes only after a bootstrap PR demonstrates a green
`merge_group` run end-to-end. Until then, Stage 1 remains the canonical
state.

### Stage 3 — Merge queue as the only path

**Status**: deferred. Blocked on Stage 2 proven.

Concrete moves:

1. Branch protection rule: require merge queue on `main`.
2. Retire the `--auto` ritual (old pattern becomes invalid — PRs enter
   queue via the "Merge when ready" UI).
3. Rebase churn becomes structurally impossible because the queue builds
   each PR against a virtual up-to-date base.

## Workflow-level requirements

Merge queue dispatches jobs under the `merge_group` event. Any workflow
producing a required status check MUST include `merge_group:` in its `on:`
triggers, else the queue will time out waiting for a check that never
fires.

Current state (verified 2026-04-20):

| Required check | Workflow file | `merge_group` trigger |
|---|---|---|
| Static Validation | `.github/workflows/ci.yml` | ✓ present |
| Tutor Configuration Tests | `.github/workflows/ci.yml` | ✓ present |
| Security Scans | `.github/workflows/ci.yml` | ✓ present |
| Python test coverage | `.github/workflows/ci.yml` | ✓ present |
| Review dependencies | `.github/workflows/dependency-review.yml` | ✓ present |
| Trivy — K8s Manifests | `.github/workflows/iac-scan.yml` | ✓ present |
| Trivy — Terraform | `.github/workflows/iac-scan.yml` | ✓ present |

All 7 workflows are already wired for merge queue — Stage 2 is a config
change, not a CI project. The trigger was added in PR #1526 (fastlane CI
restructure, 2026-04-10).

## What this policy does NOT cover

- **bbi-infrastructure** has its own merge policy — currently `strict:
  false` live with a target of `true` (tracked as enforcement debt in
  `branch-protection-contract.yaml`). Out of scope for this document.
- **PR review requirements** remain `0` required reviewers (agent-authored,
  owner-merged). Policy driven by CLAUDE.md standing order, not this doc.
- **Admin bypass** remains `enforce_admins: true` for mereka-lms. No
  emergency bypass is policy-authorized.

## Verification

```
# Live protection state
gh api /repos/Biji-Biji-Initiative/mereka-lms/branches/main/protection \
  --jq '.required_status_checks | {strict, contexts_count: (.checks // .contexts | length)}'

# Contract check (CI-gated)
bash scripts/qa/verify-branch-protection-contract.sh

# Merge queue rulesets (Stage 2+)
gh api /repos/Biji-Biji-Initiative/mereka-lms/rulesets
```

## Related

- `config/branch-protection-contract.yaml` — machine-checkable live/target
- `scripts/qa/verify-branch-protection-contract.sh` — CI gate
- GitHub docs: [Merging a pull request with a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)
- PR #1526 — original `merge_group:` trigger introduction
