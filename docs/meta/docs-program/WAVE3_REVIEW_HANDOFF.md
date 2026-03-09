# Wave 3 Review Handoff

## Review focus

- Confirm the twin-root model is now physically true: normative root specs remain normative, proposal material lives under `specs/proposals/`, and plans/testplans live under `specs/plans/`.
- Confirm compatibility wrappers are minimal and treated as generated compatibility surfaces rather than normative root truth in generated outputs.
- Confirm validator behavior now matches repo reality across all lane files.

## Intentional holdouts

- `specs/data-migrations-kajabi-mct_spec.md` remains normative by explicit decision.
- `specs/plans/data-migrations-kajabi-mct_plan.md` remains the execution companion.

## Key packet commits

- `f327c083720798860def9c06fb3c1ae91d8e3bb9` `docs: make generated spec surfaces wrapper-aware`
- `532e74f2691e63d15ea2350059ce2ade9cc34185` `docs: clear proposal legacy status tail`
- `e86c64ff5805614f59b389f582e7fc5c67a6c797` `fix: harden lane taxonomy enforcement`
- `bc22409c3316a7cdf017518c34ba1c257d09380a` `docs: close out wave 3 twin-root run`

## Final metric state

- normative specs: 44
- proposal specs: 4
- plan files: 60
- missing required metadata: 0 across all lanes
- legacy status hits: 0
- top-level non-normative root residue: 0

## Recommended reviewer path

- Start with `docs/meta/docs-program/WAVE3_CLOSEOUT.md`.
- Validate the final policy state in `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`.
- Spot-check generated truth surfaces in `specs/catalog.json`, `specs/INDEX.md`, and `specs/_generated/graph.json`.
