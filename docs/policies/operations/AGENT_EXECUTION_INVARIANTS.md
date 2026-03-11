# Agent Execution Invariants

This document is the repo-side operating contract for agent execution in `mereka-lms`.

It exists to make the following failure patterns harder to recreate:

1. execution context drift
2. dirty-tree mutation
3. weak governance awareness
4. stale worktree mutation
5. assumed runner capabilities
6. evidence-free mutation
7. proof/repair mixing
8. live mutation without ledgering
9. real-account or credential boundary violations
10. ambiguous build truth
11. weak lane scope enforcement

See also:
- `docs/reference/operations/EXECUTION_CONTEXT_LOCK.md`
- `docs/reference/operations/MUTATION_CLASS_MATRIX.md`
- `docs/reference/operations/PROOF_REPAIR_SEPARATION_PROTOCOL.md`
- `docs/reference/operations/REAL_ACCOUNT_AND_CREDENTIAL_BOUNDARY.md`
- `docs/reference/operations/LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md`
- `docs/reference/operations/RUNNER_CAPABILITY_CONTRACT.md`
- `docs/reference/operations/BUILD_TRUTH_CONTRACT.md`
- `docs/reference/operations/execution-invariants-pack.v1.yaml`

## 1. Context Lock

An agent MUST print and verify a context lock before any mutation. The lock MUST name:

- repo
- branch
- worktree
- lane
- target environment
- allowed mutation class
- task or PR identifier
- evidence intent

The required lock fields and valid examples live in `EXECUTION_CONTEXT_LOCK.md`.

No mutation is allowed if the lock is absent, stale, or contradicted by the actual git context.

## 2. Clean Transaction Boundary

An agent MUST NOT mutate from:

- a dirty working tree it did not intentionally create
- unresolved stash state
- an ambiguous worktree
- an unknown branch tip
- mixed branch + worktree ownership

Before mutation, the agent MUST confirm:

- `git status --short` is clean or intentionally scoped to the lane's own work
- the current worktree is the intended worktree for the lane
- the branch is dedicated to the current task
- there is no unresolved local stash or detached-head ambiguity

If any of these checks fail, the agent MUST stop and either cleanly isolate the work or escalate.

## 3. Mutation Classes

Every task MUST declare exactly one mutation class before work begins:

- `repo-only`
- `gitops-only`
- `live-proof-only`
- `live-mutation-exception`

The full class matrix is in `MUTATION_CLASS_MATRIX.md`.

Rules:

- A lane MUST NOT silently switch classes mid-task.
- A proof lane MUST NOT repair.
- A repair lane MUST NOT claim proof beyond its mutation class.
- `live-mutation-exception` is prohibited by default and requires explicit approval plus ledgering.

## 4. Evidence Before Mutation

Before any mutation, the agent MUST capture enough evidence to answer:

- what is broken
- which source of truth owns the broken behavior
- whether the action is repo-only, GitOps-only, proof-only, or prohibited
- what exact artifact will prove the fix

Allowed evidence includes:

- exact CI logs
- repo verifiers
- static file inspection
- build metadata
- prior reviewer artifacts

Live mutation without pre-mutation evidence is prohibited.

## 5. Proof vs Repair Separation

Proof and repair are different operations and MUST NOT be blurred.

- Proof answers what is true.
- Repair changes what is true.

An agent MUST follow the sequence in `PROOF_REPAIR_SEPARATION_PROTOCOL.md`.

Claims are constrained by class:

- proof lanes may conclude observed truth only
- repair lanes may claim durable repo change only
- no lane may claim live runtime success from repo-only evidence

## 6. Real-Account / Credential Prohibition

Agents operating under this repo contract MUST NOT:

- change real user or operator passwords
- log in with real operator identities for proof
- recover access by ad hoc credential manipulation
- use browser proof against real accounts
- move or reveal real credentials in logs, comments, or evidence

The exact boundary is defined in `REAL_ACCOUNT_AND_CREDENTIAL_BOUNDARY.md`.

Any exception is prohibited unless explicitly approved and logged as a live mutation exception.

## 7. Scope Guardrails By Lane

Every lane MUST name:

- what it owns
- what it does not own
- which repos it may touch
- which mutation class it may use

Lane drift is a contract violation. Examples:

- a repo-only lane MUST NOT mutate runtime state
- a GitOps lane MUST NOT backfill app-repo runtime logic
- a proof lane MUST NOT ship repairs and call them proof
- a docs or control lane MUST NOT reopen product or runtime investigations

If the actual blocker lives outside the lane, the lane MUST record that once and stop expanding scope.

## 8. Build Truth Contract

Build truth MUST be explicit and reproducible.

Agents MUST NOT rely on:

- `latest` as required truth
- hidden package rescue
- ambiguous cache state
- implicit package access
- unstated runner privileges

Agents MUST record:

- exact source ref, tag, or digest
- whether cache was used
- package access assumptions
- the verifier or artifact that proves the resulting build truth

The full contract is in `BUILD_TRUTH_CONTRACT.md`.

## 9. Exception Handling And Escalation

If a task appears to require out-of-class mutation, the agent MUST:

1. stop
2. capture evidence
3. classify the required mutation
4. record why the current lane cannot own it
5. escalate or request reassignment

If a live mutation is explicitly approved, the agent MUST log it using `LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md`.

## 10. Required Output Format For Lane Updates

Every lane update MUST use this exact section set:

1. Lane / repo / worktree truth
2. Current owned blocker
3. What changed since last report
4. Files created or modified
5. Policy / control findings
6. Decisions made
7. Live-write actions intentionally NOT taken
8. Remaining blockers with owners
9. Final status
10. Next action already in motion

Allowed final status enums:

- `IN_PROGRESS`
- `READY_FOR_REVIEW`
- `COMPLETE`

## Operating Summary

The invariant is simple:

- lock context before mutation
- mutate only from a clean and declared state
- gather evidence before changing anything
- keep proof and repair separate
- never cross the real-account or credential boundary
- record any approved live mutation in a durable ledger
- make build truth explicit, not assumed

