# Duplicate Writer Retirement Register

_Owner: Agent 2 | Last verified: 2026-04-10T10:53:23Z | Status: active_

## Active Duplicate Writers In The Promotion Lane

| # | Concern | Canonical should be | Current shadow writers | Status | Exit plan |
|---|---|---|---|---|---|
| 1 | Release bundle contract | PCP release bundle schema | app generator + app JSON schema + local verifier semantics | open | consume PCP schema directly or regenerate local schema from PCP |
| 2 | Release object contract | one canonical contract surface | `schemas/release-object.schema.json`, generator, infra receiver checks | narrowed: stale YAML authority retired in app repo, PCP authority still open | move authority to PCP or generate both app/infra validators from one contract |
| 3 | Dispatch payload contract | PCP dispatch contract | sender workflow code + receiver workflow code | open | define PCP contract and validate on both sides |
| 4 | Dev promotion evidence shape | PCP `promotion_record` family | `dev_promotion_record` in `promote-dev-image.yml` | open | emit canonical promotion-record-compatible object for dev lane |
| 5 | Lane normalization semantics | PCP lane/service identity contracts | `config/lane-identity.yaml` + `scripts/lib/lane-normalize.sh` | open | generate projection from PCP or consume PCP directly |
| 6 | Control-plane reference pin | explicit governed PCP ref | repo-local hardcoded PCP refs across generators/proof/tests | source-fixed locally, governance open | replace hardcoded refs with governed PCP ref selection so future updates do not require manual repo sweeps |
| 7 | GitOps mutation path | automated dispatch path | manual `update-gitops` bridge in `build-tutor-images.yml` | open | retire manual bridge after realized/runtime proof on the automated lane |
| 8 | Proof-gate semantics | PCP proof-gate authority | inlined workflow behavior and app-local shims | open | point workflow enforcement to PCP-owned gate IDs/contracts |

## Narrow Drift Reduced This Tranche

| Concern | Change |
|---|---|
| Local release-bundle JSON schema vs generator | aligned on `schema_version: "1.1"` and `contract_family: "release_bundle_schema"` in this repo |
| Local release-object schema authority | retired stale `config/release-object-schema.yaml`; app verifiers now point at the real JSON schema projection |

## What Is Not Retired Yet

- The local release-bundle schema now matches the local generator on version/family, but the broader PCP-vs-app authority split still exists.
- The release-object contract remains the largest unresolved duplicate-writer seam.
- The dev lane still emits ad hoc promotion evidence instead of the canonical promotion-record family.
