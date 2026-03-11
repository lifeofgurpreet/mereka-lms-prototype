# Execution Context Lock

This document defines the minimum context lock every agent MUST print before any mutation.

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

Machine-readable contract:
- `docs/reference/operations/execution-invariants-pack.v1.yaml`

## Required Fields

Every context lock MUST include:

- `repo_name`
- `repo_path`
- `worktree_path`
- `branch`
- `baseline_ref`
- `lane`
- `task_or_pr`
- `target_environment`
- `mutation_class`
- `scope_statement`
- `evidence_plan`
- `live_mutation_allowed`
- `real_account_access`

## Valid Lock Rules

A valid lock MUST satisfy all of the following:

1. `repo_path` matches the actual repo root.
2. `worktree_path` matches the active worktree where files will change.
3. `branch` matches the current checked-out branch.
4. `baseline_ref` identifies the comparison base used for truth.
5. `lane` states the lane identity, not a vague team name.
6. `target_environment` names the intended environment or explicitly says `none`.
7. `mutation_class` is one of the allowed classes.
8. `scope_statement` explicitly names what the lane will not touch.
9. `live_mutation_allowed` is `false` unless an exception is approved.
10. `real_account_access` is `prohibited` for normal operation.

## What Invalidates A Lock

A previously captured lock becomes invalid when:

- the repo changes
- the worktree changes
- the branch changes
- the task pivots
- the target environment changes
- the mutation class changes
- the working tree becomes dirty from unrelated state
- a stash is applied or popped
- a live mutation is proposed without a new lock and exception record

When invalidated, the lock MUST be re-captured before any further mutation.

## Correct Example

```text
repo_name: mereka-lms
repo_path: /home/gurpreet/projects/k8s/mereka-lms-wt-lane-e-invariants
worktree_path: /home/gurpreet/projects/k8s/mereka-lms-wt-lane-e-invariants
branch: lane-e/execution-invariants-pack
baseline_ref: origin/main
lane: Lane E
task_or_pr: execution-invariants-pack
target_environment: none
mutation_class: repo-only
scope_statement: repo-side docs, verifier, and static wiring only; no runtime, no bbi-infrastructure, no kubectl
evidence_plan: local verifier + static registry diff + reviewer summary
live_mutation_allowed: false
real_account_access: prohibited
```

## Incorrect Examples

Incorrect because the branch is omitted:

```text
repo_path: /home/gurpreet/projects/k8s/mereka-lms
lane: Lane E
mutation_class: repo-only
```

Incorrect because the lock allows undeclared live mutation:

```text
target_environment: prod
mutation_class: repo-only
live_mutation_allowed: maybe
```

Incorrect because the scope is fuzzy:

```text
scope_statement: will fix whatever is needed
```

## Minimum Rule

If an agent cannot print a valid context lock, the agent MUST NOT mutate.

