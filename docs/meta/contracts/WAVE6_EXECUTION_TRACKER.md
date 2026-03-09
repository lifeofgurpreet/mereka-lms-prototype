# Wave 6 Execution Tracker

## Current branch
- docs/wave6-cross-repo-contract-runtime

## Latest substantive packet head
- Packet D commit on docs/wave6-cross-repo-contract-runtime

## Last completed batch
- commit: Packet D commit on docs/wave6-cross-repo-contract-runtime
- scope: Packet D cross-repo impact engine
- validators run:
  - Packet D cross-repo manifest write/check
  - Packet D deployment impact report write/check
  - bash scripts/qa/run-knowledge-runtime-gates.sh
  - python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
- result: complete

## Packets completed
- Packet A: contract schema
- Packet B: service contract inventory
- Packet C: infra crosswalk
- Packet D: cross-repo impact engine

## Current target batch
- files:
  - tools/contracts/build_release_obligations.py
  - generated/contracts/release-obligations.md
- goal:
  - generate the human-facing release packet for deployment-affecting changes
  - make required infra follow-up and evidence obligations reviewer-readable
- stop condition:
  - one generated release packet can explain deployment obligations for the branch diff
  - Wave 5 runtime stays green
  - one commit is created

## Locked decisions
- Wave 4 topology stays intact
- Wave 5 change intelligence remains the repo-native base layer
- Wave 6 is repo-contract-only and does not reconcile live clusters
- docs/ and specs/ remain separate filesystem roots
- cross-repo unknowns are allowed only when explicit and reviewable

## Open unknown mappings
- openedx: exact ArgoCD application and secret-store file paths remain unknown, but overlay roots are mapped
- mfe: exact ingress, appset, and edge file paths remain unknown, but overlay roots are mapped
- purchase-gateway: exact Stripe secret and ingress file paths remain unknown, but overlay roots are mapped
- enterprise-services: per-service overlay decomposition remains unknown
- runner-ci: exact self-hosted runner host and secret provisioning file paths remain unknown
- observability-runtime: exact monitoring and alerting app file paths remain unknown

## Services with no contract inventory
- none

## Next queued batch
- Packet D: cross-repo impact engine
- Packet E: release obligations engine
