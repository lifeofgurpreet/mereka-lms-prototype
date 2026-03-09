# Wave 6 Execution Tracker

## Current branch
- docs/wave6-cross-repo-contract-runtime

## Latest substantive packet head
- Packet C commit on docs/wave6-cross-repo-contract-runtime

## Last completed batch
- commit: Packet C commit on docs/wave6-cross-repo-contract-runtime
- scope: Packet C infra crosswalk
- validators run:
  - Packet C service-to-crosswalk coverage check
  - bash scripts/qa/run-knowledge-runtime-gates.sh
  - python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
- result: complete

## Packets completed
- Packet A: contract schema
- Packet B: service contract inventory
- Packet C: infra crosswalk

## Current target batch
- files:
  - tools/contracts/build_cross_repo_manifest.py
  - tools/contracts/build_deployment_impact_report.py
  - generated/contracts/cross-repo-manifest.json
  - generated/contracts/deployment-impact-report.json
- goal:
  - project app-repo changes onto infra counterpart obligations
  - classify cross-repo impact as required, not required, manual review, or unknown
- stop condition:
  - branch diff can be classified into app-only, infra-coupled, or unknown-impact
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
