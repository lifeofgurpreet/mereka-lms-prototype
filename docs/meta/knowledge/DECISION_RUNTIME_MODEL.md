# Decision Runtime Model

Wave 12 converts the Wave 11 pack runtime into a deterministic review and release decision system.

## Canonical inputs

Canonical machine inputs, in precedence order:

1. `generated/skills/pack-registry.json`
2. `generated/skills/skill-registry.json`
3. `generated/skills/runtime-convergence-report.json`
4. `generated/skills/evidence-sufficiency-map.json`
5. `generated/skills/mixed-diff-arbitration.json`
6. canonical repo truth referenced by those packs:
   - contracts
   - registries
   - specs
   - standing orders
   - verification entrypoints
7. generated projections such as `generated/skills/read-first.md` and future Wave 12 markdown outputs

Generated markdown is projection only. It cannot outrank the machine-readable payloads that produced it.

## Resolver precedence

The decision runtime resolves a diff in this order:

1. `pack-registry`
   - determines which canonical machine packs exist and can be trusted
2. `skill-registry`
   - determines which skills are relevant, which repos they apply to, and which packs/commands they depend on
3. `runtime-convergence-report`
   - determines whether cross-repo repo-truth is aligned or carrying warnings/failures
4. `evidence-sufficiency-map`
   - determines which evidence classes are mandatory and which missing classes block
5. `mixed-diff-arbitration`
   - determines merge rules when categories overlap
6. canonical repo truth
   - used only to justify or explain machine decisions, not to bypass them

## Decision outputs

Wave 12 produces these canonical machine outputs:

- `review-decision.json`
- `reviewer-obligations.json`
- `evidence-obligations.json`
- `read-first-packs.json`
- `release-readiness.json`
- `runtime-evaluation.json`

And these projections:

- `review-decision.md`
- `release-readiness.md`

## Review decision

A review decision answers:

- what diff range was evaluated
- which repos and roots were touched
- which skill categories fired
- whether the change is low, medium, high, or release-critical
- whether the change is blocking or non-blocking
- which reviewers are required
- which read-first packs should be consumed first
- which canonical inputs produced the decision

## Evidence obligations

Evidence obligations are computed from:

- required evidence classes on the selected skills
- sufficiency rules in `evidence-sufficiency-map.json`
- arbitration merge rules for overlapping categories

Evidence obligations are:

- blocking when a high-risk or release-related skill requires them
- advisory when they arise only from non-blocking or review-only categories

## Release readiness

Release readiness is computed from:

- review decision severity
- required evidence obligations
- required reviewer obligations
- runtime convergence report status
- mixed-diff arbitration rules

The allowed verdicts are:

- `ready`
- `blocked`
- `advisory`
- `break-glass-only`

`break-glass-only` is reserved for diffs that touch release/control-plane surfaces but lack normal sufficiency or convergence confidence while still exposing an explicit exceptional path.

## Mixed diffs

When a diff spans docs, specs, workflows, contracts, and release surfaces:

- reviewer requirements union first, then prioritize the primary reviewer strategy named by the arbitration rule
- evidence classes union first, then apply the arbitration rule's merge strategy
- read-first order is driven by the arbitration rule's `primary_read_first_skill`
- any unresolved contradiction between runtime convergence, reviewer obligations, and evidence obligations becomes blocking

## Deterministic vs advisory

Deterministic:

- touched repos/roots
- selected skills
- required reviewers from current repo truth
- required evidence classes from current repo truth
- read-first pack ordering
- runtime convergence pass/warning/fail state

Advisory:

- human interpretation of whether an unresolved warning is acceptable
- live approval state outside repo truth
- live deployment/runtime state outside repo truth

## Blocking rules

A decision must be blocking when any of the following are true:

- a required canonical pack is missing
- a required skill is missing
- a required reviewer group cannot be derived
- a required evidence class cannot be derived
- runtime convergence reports a fail
- mixed-diff arbitration cannot resolve a high-risk overlap

Warnings remain non-blocking only when:

- the underlying pack/runtime inputs stay present and schema-valid
- the warning is explicitly marked unresolved but non-failing in runtime convergence

## Non-goals

The decision runtime does not:

- guess live GitHub approval state
- guess live cluster state
- use LLM judgment to resolve ambiguity
- treat archive or transitional paths as canonical
