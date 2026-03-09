# Wave 5 Change Runtime Closeout

## What Wave 5 added

- A machine-readable ownership and review schema for truth lanes and high-risk surfaces.
- A change manifest engine that classifies a branch diff into normative, proposal, plan, wrapper, generated, evidence, and handoff change classes.
- A reviewer bundle that turns the branch diff into one reviewer-facing read-first packet.
- A truth impact report that projects changed files onto ADRs, plans, wrappers, runbooks, and generated surfaces.
- A wrapper retirement runtime report that classifies wrappers as active-and-justified, active-but-suspicious, suspicious, or safe-to-retire.
- A runtime verifier and one end-to-end Wave 5 gate, wired into `docs-policy.yml`.

## What stayed intentionally unchanged

- Wave 4 topology remains intact.
- `docs/` and `specs/` remain separate filesystem roots.
- Wave 3 normative decisions remain locked, including the Kajabi/MCT holdout.
- Compatibility wrappers remain explicit compatibility surfaces; they do not regain normative standing.

## Current runtime posture

- Change intelligence is now repo-native rather than reviewer memory.
- One branch diff can now be classified deterministically.
- One reviewer bundle can now be generated automatically.
- One truth impact report can now project downstream knowledge fallout.
- Wrapper retirement candidates and suspicious wrappers are visible without manual grep loops.

## Recommended reviewer path

1. Run `bash scripts/qa/run-knowledge-runtime-gates.sh`.
2. Open `generated/knowledge/review-bundle.md`.
3. Check `generated/knowledge/truth-impact-report.json` for downstream truth fallout.
4. Check `generated/knowledge/wrapper-retirement-report.json` for suspicious wrappers.
5. Use `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md` as the human operating model.

## Recommended next wave

- Use the Wave 5 runtime in real PR review flow and tune review/evidence rules only where live review data shows false positives or blind spots.
