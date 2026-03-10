# Wave 14 Execution Tracker

## Latest substantive packet head
- b56825ee5731b95b0c72d89486ec149cbefec74d

## Last completed batch
- commit: b56825ee5731b95b0c72d89486ec149cbefec74d
- scope: Wave 14 Packet D human handbook pages
- validators run: docs catalog rebuild, docs catalog governance, local link integrity for handbook pages
- result: thin handbook pages exist and route readers back to the generated references

## Current target packet
- files:
  - tools/docs/verify/verify_team_handbook.py
  - scripts/qa/run-team-handbook-gates.sh
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
- goal:
  - enforce handbook structure and no-drift rules locally
  - make generated references and footer requirements machine-checkable
  - prepare the wave for minimal CI adoption
- stop condition:
  - handbook verifier passes
  - dedicated handbook gate passes
  - docs governance still passes on the full Wave 14 diff

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
- Packet F: link the handbook from canonical front doors and write closeout/handoff
