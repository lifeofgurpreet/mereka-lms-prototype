# Wave 14 Execution Tracker

## Latest substantive packet head
- e1ff43e6b322bdde9308703c5976a97786a90950

## Last completed batch
- commit: e1ff43e6b322bdde9308703c5976a97786a90950
- scope: Wave 14 Packet C team topology reference generator
- validators run: team topology generator write/check, docs catalog rebuild, docs catalog governance
- result: lane topology and shared-versus-tenant behavior are machine-backed and linked to Packet B conflict evidence

## Current target packet
- files:
  - docs/guides/platform/PLATFORM_START_HERE.md
  - docs/guides/platform/OPENEDX_FOR_TEAM_MEMBERS.md
  - docs/guides/platform/COURSE_AUTHORING_QUICKSTART.md
  - docs/guides/platform/OPENEDX_SETTINGS_MATRIX.md
  - docs/guides/platform/MULTI_TENANCY_EXPLAINED.md
  - docs/guides/platform/SUPPORT_AND_ESCALATION.md
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
- goal:
  - write the thin human handbook pages on top of the generated references
  - keep volatile facts out of handbook prose
  - link generic product behavior to official Open edX and Tutor docs instead of duplicating it
- stop condition:
  - all six handbook pages exist with the required footer block
  - handbook prose points back to generated references for volatile facts
  - docs governance and local link integrity pass for the new handbook pages

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
- Packet E: add handbook verification and a dedicated handbook gate
