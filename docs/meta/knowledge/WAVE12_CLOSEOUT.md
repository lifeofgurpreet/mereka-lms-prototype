# Wave 12 Closeout

Wave 12 turns the Wave 11 pack and skill runtime into a deterministic review and release decision runtime.

## What Wave 12 Added
- Canonical decision runtime model in [DECISION_RUNTIME_MODEL.md](/home/gurpreet/projects/k8s/mereka-lms-wt-wave12-review-release-decision-runtime/docs/meta/knowledge/DECISION_RUNTIME_MODEL.md)
- Machine-readable decision outputs:
  - `generated/knowledge/review-decision.json`
  - `generated/knowledge/reviewer-obligations.json`
  - `generated/knowledge/evidence-obligations.json`
  - `generated/knowledge/read-first-packs.json`
  - `generated/knowledge/release-readiness.json`
  - `generated/knowledge/runtime-evaluation.json`
- Human-facing projections:
  - `generated/knowledge/review-decision.md`
  - `generated/knowledge/release-readiness.md`
- Fixture-backed evaluation under `fixtures/decision-runtime/`
- One decision-runtime verifier and one local/CI gate

## Canonical vs Projection
- Canonical machine truth:
  - the six `generated/knowledge/*.json` decision outputs
  - schemas under `docs/meta/knowledge/schemas/`
  - generators under `tools/knowledge/`
- Projections:
  - `generated/knowledge/review-decision.md`
  - `generated/knowledge/release-readiness.md`

## What The Runtime Now Guarantees
- A diff range deterministically produces:
  - review decision
  - reviewer obligations
  - evidence obligations
  - read-first pack order
  - release readiness verdict
  - runtime evaluation against fixtures
- High-risk changes cannot pass the decision runtime without:
  - required reviewer groups
  - evidence obligations
  - explainable canonical inputs
- Decision outputs are schema-validated and CI-checked.

## What It Does Not Guarantee
- live GitHub approval state
- live cluster/runtime convergence
- rebuilt external Wave 11 assistant/front-door exports
- presence of Wave 10 generated agent packs on a mainline-based branch where they were not yet merged

## Remaining Risks
- assistant surface exports are not yet rebuilt on the fresh Wave 11 external branches
- Wave 10 generated agent packs are not present on this mainline-based Wave 12 branch
- runtime convergence warnings still require human follow-up

## Recommended Wave 13
- bind decision outputs to execution receipts and approval receipts
- attach runtime proof bundles to release readiness and evidence sufficiency
- reduce remaining branch-state dependencies between Wave 10, Wave 11, and Wave 12 surfaces
