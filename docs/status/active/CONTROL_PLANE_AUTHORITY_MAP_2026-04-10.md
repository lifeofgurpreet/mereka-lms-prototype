# Control-Plane Authority / Migration Map

_Owner: Agent 2 | Last verified: 2026-04-10T10:53:23Z | Status: active_

## PCP Canonical Now

| Concern | PCP authority | Current PCP head |
|---|---|---|
| release bundle / evidence pack / promotion record | `contracts/release-bundle-schema.yaml`, `contracts/evidence-pack-schema.yaml`, `contracts/promotion-record-schema.yaml` | `194e6001c924902e8bf3dafefdc37fc842c56653` |
| release object authority map | `contracts/release-object-authority-contract.yaml` | same |
| lane / service identity | `contracts/lane-identity-contract.yaml`, `contracts/service-identity-contract.yaml` | same |
| proof gate / domain proof policy | PCP now owns the migrated contracts via PR `#75` on `main` | same |

## Still Local Or Split In App / Infra

| Concern | Current local reality | Status |
|---|---|---|
| release-object schema | app YAML schema, app JSON schema, generator, and infra receiver all define behavior | split |
| dispatch contract | sender and receiver code agree by convention only | split |
| lane semantics in promotion tooling | app `config/lane-identity.yaml` + `scripts/lib/lane-normalize.sh` still mediate env normalization | split |
| dev promotion evidence | infra dev workflow writes `dev_promotion_record`, not canonical PCP `promotion_record` | split |
| control-plane ref pin | core generators/proof scripts now pin `platform-control-plane@194e6001...` locally, but ref choice is still repo-local policy | split |

## What Should Move Next

| Priority | Move | Why |
|---|---|---|
| High | Dispatch payload contract | current sender/receiver agreement is real but implicit |
| High | Release-object contract authority | biggest remaining duplicate-writer seam in the promotion chain |
| Medium | Dev promotion evidence into canonical `promotion_record` family | dev lane currently forks the evidence shape from staging/prod |
| Medium | Contract-ref pin governance | emitted artifacts now point at current PCP `main` locally, but the choice is still hardcoded instead of governed |
| Medium | Lane-normalize projection generation from PCP | remove bash/config drift risk |

## What Should Not Move Yet

| Concern | Why it should stay local for now |
|---|---|
| `generate_truth_ledger.py` implementation | app-specific joiner over repo/release/runtime proof planes |
| runtime-routing / acceptance summary details | runtime lane logic belongs to app/runtime proof tooling |
| build job orchestration | CI mechanics are app-repo behavior, not control-plane law |
| tenant contract hashing inside release object | app release object still needs app-local source proof |

## Current Authority Delta

- PCP is ahead of the app repo on canonical contract ownership.
- The app repo has already partially migrated proof-gate/domain-proof contracts out.
- The promotion lane is not yet control-plane-led because the live handoff still hinges on repo-local `release-object/v1` checks and an implicit dispatch schema.
- Any claim that `5fffde1a` is the current PCP baseline is stale; current `origin/main` is `194e6001c924902e8bf3dafefdc37fc842c56653`, and the local promotion generators were updated this tranche to stop emitting the old ref.
