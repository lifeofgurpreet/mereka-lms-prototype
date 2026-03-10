# Wave 14 Execution Tracker

## Latest substantive packet head
- c0ac67a289fe6c3f0cf0885c038d4741f3d5f836

## Last completed batch
- commit: c0ac67a289fe6c3f0cf0885c038d4741f3d5f836
- scope: Wave 14 Packet A rebased onto the reconciled Wave 10-13 runtime base
- validators run: docs catalog rebuild, docs catalog governance, source path existence checks
- result: handbook topology is locked on the reconciled base and catalog-visible

## Current target packet
- files:
  - tools/docs/build_domain_access_reference.py
  - generated/platform/domain-access-reference.json
  - docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
- goal:
  - generate the domain and access reference from canonical inputs
  - keep registry-backed main tenant domains machine-derived
  - make cross-reference conflicts explicit instead of guessing tenant URLs
- stop condition:
  - canonical JSON output exists and passes `--check`
  - markdown projection exists and is clearly generated
  - unresolved tenant URL conflicts are explicit rather than silently normalized
  - docs governance passes with the new reference surface

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
- Packet C: generate `generated/platform/team-topology-reference.json` and project it to `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
