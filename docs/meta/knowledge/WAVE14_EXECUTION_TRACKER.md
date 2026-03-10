# Wave 14 Execution Tracker

## Latest substantive packet head
- 53b1e9f35e78d58ced4dc9a55cb061aca9f98c6f

## Last completed batch
- commit: 53b1e9f35e78d58ced4dc9a55cb061aca9f98c6f
- scope: Wave 14 Packet E handbook verifier and CI adoption
- validators run: handbook verifier, handbook gate, docs catalog governance, docs-policy YAML parse
- result: handbook integrity is locally enforceable and wired into docs-policy CI

## Current target packet
- files:
  - docs/README.md
  - docs/guides/README.md
  - docs/meta/knowledge/WAVE14_CLOSEOUT.md
  - docs/meta/knowledge/WAVE14_REVIEW_HANDOFF.md
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
- goal:
  - make the handbook discoverable from canonical docs front doors
  - leave closeout and review handoff documents for reviewers and future agents
  - finish the wave without creating a new parallel truth plane
- stop condition:
  - handbook is reachable from canonical docs front doors
  - closeout and review handoff exist
  - tracker reflects the final wave state

## Locked handbook topology
- human-authored handbook root: `docs/guides/platform/`
- generated reference root: `docs/reference/platform/`
- machine-readable generated root: `generated/platform/`
- generator and verifier root: `tools/docs/`
- QA gate entrypoint: `scripts/qa/run-team-handbook-gates.sh`
- canonical docs front door to update in Packet F: `docs/README.md`

## Packet plan
- Packet A: structure, tracker, source map
- Packet B: generated domain and access reference
- Packet C: generated team topology reference
- Packet D: thin handbook prose pages
- Packet E: handbook verifier and CI adoption
- Packet F: front-door linking, closeout, and review handoff

## Open residue
- base `main` is current with `origin/main`, but the base checkout is dirty and must remain untouched during Wave 14
- some historical Wave 10 example paths named in the brief are not present on the current `main` checkout; Wave 14 must anchor to live canonical paths on the reconciled Wave 10-13 lineage instead of recreating them
- SkillOurFuture production Studio and MFE URLs are currently in conflict between `DOMAIN_MATRIX.md` and `USER_FACING_URLS.md`; Packet B records the conflict instead of inventing a winner
- live approval state, live runtime evidence attachment, and vendor bot integrations remain intentionally unresolved outside the scope of this handbook wave

## Next queued packet
- none
