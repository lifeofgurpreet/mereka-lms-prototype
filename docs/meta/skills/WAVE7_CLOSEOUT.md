# Wave 7 Closeout

## What Wave 7 added

- A first-class task taxonomy for agent-consumable work over the existing docs,
  specs, review, and contract runtimes.
- A deterministic task context resolver that maps a diff or explicit task type to
  canonical surfaces, reviewers, evidence, commands, and escalation conditions.
- Generated task bundles for the ten supported task types.
- A generated skill index that gives agents and humans one stable entrypoint into
  the bundle set.
- A generated task-context report that resolves the current diff into primary and
  secondary task types, confidence, reviewers, evidence, and command obligations.
- A task-runtime verifier and gate that keeps the bundle layer truthful and aligned
  with Wave 5 and Wave 6 policy.

## What Wave 7 intentionally did not change

- Wave 4 canonical roots and lane topology.
- Wave 5 review and evidence policy semantics.
- Wave 6 cross-repo contract semantics.
- Wrapper retirement policy or archive topology.
- The Kajabi/MCT normative holdout decision.

## Final task types

- `normative_spec_change`
- `proposal_or_rfc_change`
- `architecture_or_adr_change`
- `cross_repo_contract_change`
- `release_or_runtime_change`
- `runbook_or_ops_change`
- `evidence_or_status_change`
- `generated_surface_refresh`
- `compatibility_or_wrapper_cleanup`
- `reviewer_handoff_or_policy_change`

## What agents can now do deterministically

- infer likely task type candidates from a diff range
- resolve canonical read-first surfaces for the task
- see required reviewers and evidence without grepping multiple policy files
- know which generated surfaces must be refreshed
- know which validators to run
- see when a task crosses into cross-repo dependency or human-judgment territory

## Intentional limitations

- mixed high-risk diffs still require human judgment even when the runtime classifies them
- reviewer and evidence expectations remain strongest for Wave 5 and Wave 6 backed task types
- live-cluster reconciliation is still out of scope
- exact agent orchestration behavior is not enforced here; Wave 7 exposes the interface, not the executor

## Recommended next wave

- Wave 8 should turn the task interface into a true agent operating layer:
  authority boundaries, execution receipts, deterministic handoffs, and
  machine-verifiable closure across orchestrator, research, and coding agents
