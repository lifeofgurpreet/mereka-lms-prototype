# Wave 14 Execution Tracker

## Latest substantive packet head
- b872dd40c51cdcfb6def3e05c32e698236379436

## Last completed batch
- commit: b872dd40c51cdcfb6def3e05c32e698236379436
- scope: Wave 14 Packet B domain and access reference generator
- validators run: domain access generator write/check, docs catalog rebuild, docs catalog governance
- result: canonical access JSON exists and explicit SkillOurFuture URL conflicts are machine-visible

## Current target packet
- files:
  - tools/docs/build_team_topology_reference.py
  - generated/platform/team-topology-reference.json
  - docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md
  - docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md
- goal:
  - generate a machine-backed topology reference from lane, domain, and contract inputs
  - explain shared-versus-tenant-specific topology without inventing new truth
  - carry forward Packet B conflicts without silently normalizing them
- stop condition:
  - canonical topology JSON output exists and passes `--check`
  - markdown projection exists and is clearly generated
  - shared and tenant-specific topology rules are machine-backed
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
- Packet D: write the thin human handbook pages on top of the generated references
