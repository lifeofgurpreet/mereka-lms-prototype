# Wave 14 Execution Tracker

## Latest substantive packet head
- 191761c29aeabec3e62720bcf44e68bc640d3ec1

## Last completed batch
- commit: 191761c29aeabec3e62720bcf44e68bc640d3ec1
- scope: Wave 13 closeout baseline inherited for Wave 14 start
- validators run: inherited from Wave 13 closeout; Wave 14 Packet A validators pending on first substantive commit
- result: base is review-ready and safe to branch from

## Current target packet
- files:
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
  - docs/guides/platform/SOURCE_MAP.md
- goal:
  - lock the Wave 14 handbook tree before prose or generators land
  - map human handbook pages to canonical internal and official external sources
  - keep volatile access and topology facts on generated reference surfaces only
- stop condition:
  - tracker exists
  - handbook tree is locked under canonical docs roots
  - generated references are explicitly separated from handwritten pages

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
- some historical Wave 10 example paths named in the brief are not present on the current `main` checkout; Wave 14 must anchor to live canonical paths on the Wave 13 lineage instead of recreating them
- live approval state, live runtime evidence attachment, and vendor bot integrations remain intentionally unresolved outside the scope of this handbook wave

## Next queued packet
- Packet B: generate `generated/platform/domain-access-reference.json` and project it to `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
