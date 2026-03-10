# Wave 14 Execution Tracker

## Latest substantive packet head
- cc21ba6f2645fe5a4142a1c34c4157ec18539fe1

## Last completed batch
- commit: cc21ba6f2645fe5a4142a1c34c4157ec18539fe1
- scope: reconciled Wave 10-13 runtime lineage landed on dedicated mainline-ready branch
- validators run: docs policy, cross-repo agent gates, skill runtime gates, agent pack runtime gates, decision runtime gates, execution proof runtime gates
- result: Wave 14 now builds on the reconciled runtime base instead of the split lineage

## Current target packet
- files:
  - docs/catalog.json
  - generated/catalogs/docs-catalog.json
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
  - docs/guides/platform/SOURCE_MAP.md
- goal:
  - reassert Packet A on top of the reconciled runtime base
  - lock the Wave 14 handbook tree before prose or generators land
  - map human handbook pages to canonical internal and official external sources
  - keep volatile access and topology facts on generated reference surfaces only
- stop condition:
  - tracker exists
  - handbook tree is locked under canonical docs roots
  - docs catalog reflects the new handbook source map
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
- some historical Wave 10 example paths named in the brief are not present on the current `main` checkout; Wave 14 must anchor to live canonical paths on the reconciled Wave 10-13 lineage instead of recreating them
- live approval state, live runtime evidence attachment, and vendor bot integrations remain intentionally unresolved outside the scope of this handbook wave

## Next queued packet
- Packet B: generate `generated/platform/domain-access-reference.json` and project it to `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
