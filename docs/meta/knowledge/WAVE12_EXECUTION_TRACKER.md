# Wave 12 Execution Tracker

## Latest substantive packet head
- 7f7fe8c68eca528abecc3b19c5c1cd44ebad1fcb

## Last completed batch
- commit: 7f7fe8c68eca528abecc3b19c5c1cd44ebad1fcb
- scope: Wave 12 Packet B
- validators run: review decision generator write/check, docs catalog governance
- result: passed

## Current target packet
- files:
  - docs/meta/knowledge/schemas/reviewer-obligations.schema.json
  - docs/meta/knowledge/schemas/evidence-obligations.schema.json
  - tools/knowledge/build_reviewer_obligations.py
  - tools/knowledge/build_evidence_obligations.py
  - generated/knowledge/reviewer-obligations.json
  - generated/knowledge/evidence-obligations.json
  - docs/meta/knowledge/WAVE12_EXECUTION_TRACKER.md
- goal:
  - separate reviewer routing from evidence routing into canonical machine outputs
  - derive each from review-decision plus Wave 11 skill/evidence inputs without duplicating logic
  - make reviewer and evidence obligations independently checkable
- stop condition:
  - reviewer and evidence obligations are generated deterministically and one substantive commit is created

## Open residue
- assistant surface exports are not yet rebuilt on the fresh Wave 11 external branches
- Wave 10 generated agent packs are not present on this mainline-based Wave 12 branch
- runtime convergence warning still requires manual follow-up and must remain non-hidden in Wave 12 outputs

## Next queued packet
- Packet D: Read-first and mixed-diff arbitration runtime
