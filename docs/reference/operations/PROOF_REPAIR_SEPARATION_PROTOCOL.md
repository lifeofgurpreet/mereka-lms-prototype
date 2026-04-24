# Proof Repair Separation Protocol

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

This protocol prevents agents from mixing observation, repair, and claims.

## Required Sequence

1. Observe
   - Inspect the exact failing behavior without mutating it.
2. Capture evidence
   - Save the exact log, verifier output, or file evidence that proves the failure.
3. Classify source of truth
   - Decide whether the issue belongs to repo-only, GitOps-only, live-proof-only, or is prohibited.
4. Land durable fix
   - If the source of truth is repo-owned, change the repo and make the repair durable.
5. Re-prove
   - Run the narrow verifier or exact proof step for the repaired source of truth.
6. Close with downgraded or confirmed claim
   - Claim only what the evidence actually proves.

## Claim Discipline

- Repo-only evidence can prove repo durability.
- Repo-only evidence cannot prove live runtime success.
- Live proof can prove observed runtime state.
- Live proof cannot prove that a durable fix exists unless there is a repo or GitOps artifact.

## Prohibited Shortcuts

The following are contract violations:

- repairing before capturing evidence
- using repair artifacts as if they were proof of prior state
- claiming runtime success from static repo inspection
- mixing password resets or account changes into proof
- broadening the task mid-stream and calling it one fix

