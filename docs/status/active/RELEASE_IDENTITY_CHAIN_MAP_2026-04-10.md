# Release Identity Chain Map

_Owner: Agent 2 | Last verified: 2026-04-10T14:08:00Z | Status: active_

## Current Chain

```
build-tutor-images.yml (push to main)
  -> generate-release-bundle.sh
     bundle_id = rb-<sha8>-<timestamp>
  -> generate_release_object.py
     release_id = ro-<bundle_id>
  -> generate_truth_ledger.py
     release_truth.release_id = release_id
  -> upload artifact: release-bundle
  -> repository_dispatch promote-mereka-lms-dev
     payload carries release_bundle_id + release_object + build_provenance
  -> bbi-infrastructure promote-dev-image.yml
     validates release_object/v1 directly
     persists release-object sidecar
     creates dev overlay promotion PR
     writes dev-promotion-record.json
  -> ArgoCD realization
  -> runtime proof lane
```

## Where Identity Is Born

| Identity | Writer | Current shape |
|---|---|---|
| `bundle_id` | `scripts/infra/generate-release-bundle.sh` | `rb-<sha8>-<timestamp>` |
| `release_id` | `scripts/release/generate_release_object.py` | `ro-rb-<sha8>-<timestamp>` |

## Where Identity Is Carried

| Hop | Carrier | Current state |
|---|---|---|
| build artifact | `var/ci/release-bundle.json` + `var/ci/release-object.json` | proved |
| build ledger | `var/ci/truth-ledger.json` | proved |
| cross-repo handoff | `repository_dispatch.client_payload.release_object` | proved |
| infra promotion evidence | PR body + `var/promotion-evidence/release-object.json` | proved |
| dev promotion record | `var/promotion-evidence/dev-promotion-record.json` | proved, but not canonical PCP `promotion_record` |
| realized deployment | live cluster digest | proved for release `ro-rb-496b8a3b-20260410T065709Z` |
| runtime proof | Agent 1 lane | unproved |

## Where Identity Is Duplicated

| Concern | Canonical should be | Current duplicate writers |
|---|---|---|
| release bundle schema | PCP release bundle contract | app generator, app JSON schema, local verifier semantics |
| release object schema | one canonical contract surface | `schemas/release-object.schema.json`, generator, infra workflow validation |
| dispatch handoff | PCP dispatch contract | sender workflow code, receiver workflow code |
| dev promotion record | PCP promotion-record schema | `dev_promotion_record` ad hoc JSON in `promote-dev-image.yml` |
| control-plane ref | current PCP ref or explicit pinned release ref | core generators/proof scripts now use `194e6001...` locally, but docs/tests still rely on repo-local pinning rather than governed ref selection |

## Where Identity Is Lost Or Downgraded

| Edge | Current problem |
|---|---|
| build result -> promotion trust | push runs `24226842382` and `24227735786` failed overall, yet still emitted bundle/release object and dispatched |
| dev promotion evidence -> PCP truth | dev lane does not emit the canonical PCP `promotion_record` shape |
| release object -> PCP authority | app and infra still validate the local `release-object/v1` JSON projection instead of consuming PCP schema authority directly |
| PCP reference -> emitted artifacts | local source now points emitted artifacts at `194e6001...`, but the promotion lane still lacks an authority rule for how that ref is selected and updated |

## Realized Example: `ro-rb-496b8a3b-20260410T065709Z`

| Link | Evidence |
|---|---|
| build bundle | app run `24227735786` emitted `bundle_id = rb-496b8a3b-20260410T065709Z` |
| release object | same run emitted `release_id = ro-rb-496b8a3b-20260410T065709Z` with `openedx@sha256:0ce0538...` and `mfe@sha256:fd8e06c...` |
| dispatch evidence | infra run `24230714536` dev-promotion record carries the same `release_bundle_id`, `release_object_id`, commit `496b8a3...`, and digests |
| gitops mutation | merged infra PR [#2645](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2645) wrote the same digests into `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` |
| live realization | `./scripts/kube dev get deploy -n mereka-lms-dev` shows `lms/cms` on `openedx:496b8a3...@sha256:0ce0538...` and `mfe` on `mfe:496b8a3...@sha256:fd8e06c...` |
| remaining gap | Agent 1 has not yet attached runtime/user-path proof to the same `release_id` |

## What Moves Next To PCP

1. Dispatch payload schema and validation rules.
2. Release-object schema authority, or at minimum a PCP-owned contract consumed by app and infra.
3. Dev promotion evidence shape so dev promotions produce the same canonical identity family as staging/prod promotions.
4. Contract-ref pin governance so emitted proof states which PCP truth it actually used.
