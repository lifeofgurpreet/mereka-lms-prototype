# Mutation Class Matrix

Parent policy:
- `docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md`

Related protocols:
- `docs/reference/operations/PROOF_REPAIR_SEPARATION_PROTOCOL.md`
- `docs/reference/operations/LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md`

## Matrix

| Mutation class | Allowed tools/actions | Required evidence threshold | Forbidden actions | Exception approver |
|---|---|---|---|---|
| `repo-only` | edit files, add verifier scripts, update docs, update static registries, run local static verifiers, commit, push, open PR | exact failing file or contract, source-of-truth path, local verifier plan | kubectl, ArgoCD, browser proof with real accounts, changing secrets, changing live runtime, unlogged manual prod mutation | none; class is self-contained |
| `gitops-only` | GitOps repo edits, overlay changes, ArgoCD app wiring docs, GitOps verifier scripts | explicit repo boundary proof plus desired-state diff | app runtime edits in app repo, cluster hotfixes outside Git, proof claims without sync evidence | GitOps owner or designated operator |
| `live-proof-only` | read-only live checks, health reads, browser proof with synthetic accounts only, log inspection, read-only API checks | pre-declared proof target, allowed identity, evidence capture path | durable repair commits, password resets, credential changes, live writes | proof-lane owner |
| `live-mutation-exception` | only the exact approved live mutation plus mandatory ledgering and follow-up durable fix | explicit approval, pre-mutation evidence, revert path, durable fix target | ad hoc mutation, undocumented mutation, mutation without revert path, mutation with real credentials unless specifically approved and logged | human owner explicitly named in the ledger |

## Rules

1. Every task MUST declare exactly one class.
2. Class escalation requires a new context lock.
3. `repo-only` and `live-proof-only` MUST stay separate.
4. `live-mutation-exception` is not a convenience class. It is an escalation path.

## Evidence Threshold Meanings

- Low threshold is not allowed for mutation.
- Minimum acceptable threshold is exact evidence tied to an owning source of truth.
- High-risk classes require a revert path and durable follow-up artifact before execution.

