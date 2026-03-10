# Wave 6 Infra Crosswalk

## Purpose

This document turns repo-local deployment knowledge into a cross-repo map between:

- `mereka-lms` as the app-repo source of runtime contract intent
- `bbi-infrastructure` as the deployment-repo source of environment realization

It answers a practical question:

- if one of the major service families changes in this repo, where should reviewers expect the
  counterpart deployment work to appear?

## Boundary rule

GitOps owns environment realization, not app logic.

`bbi-infrastructure` may own:

- image pins
- ingress/TLS
- secret store wiring
- environment-specific overrides
- ArgoCD applications and appsets

`bbi-infrastructure` must not own:

- runtime Python logic
- Django settings logic
- application behavior workarounds
- long-term app logic implemented as overlay patching

## Known live overlay roots

The repo already records that active environment realization lives in the external GitOps repo:

| Environment | Live overlay root |
|---|---|
| dev | `bbi-infrastructure/apps/mereka-lms/overlays/dev/` |
| staging | `bbi-infrastructure/apps/mereka-lms/overlays/staging/` |
| prod | `bbi-infrastructure/apps/mereka-lms/overlays/prod/` |

The following app-repo overlays are deprecated as live deployment truth:

- `deploy/k8s/overlays/rke2-nonprod/`
- `deploy/k8s/overlays/staging/`
- `deploy/k8s/overlays/production/`

## Service crosswalk summary

| Service | Counterpart expectation | Current mapping quality | Notes |
|---|---|---|---|
| `openedx` | Usually cross-repo coupled | Partial | Overlay roots are known; exact app/appset filenames are not |
| `mfe` | Usually cross-repo coupled | Partial | Image and ingress realization expected in GitOps overlays |
| `purchase-gateway` | Cross-repo coupled | Partial | Stripe secret and ingress realization still need explicit mapping |
| `enterprise-services` | Often cross-repo coupled | Partial | Shared deployment edges are known, per-service decomposition is not |
| `runner-ci` | Cross-repo coupled | Partial | Release automation is known; host/runtime realization remains external |
| `observability-runtime` | Cross-repo coupled | Partial | Mixed app/infra ownership is known; exact monitoring app paths are not |

## What Packet C resolves

Packet C resolves the first-order cross-repo mapping truth:

- which overlay roots are authoritative
- which service families expect GitOps counterpart work
- which repo owns deployment realization

Packet C intentionally does not claim exact infra filenames where this repo does not prove them.

Those remain explicit unknowns until Packet D or later cross-repo inventory work can encode them.

## Source references

- `docs/meta/docs-program/boundary-debt-manifest.md`
- `docs/meta/standing-orders/GITOPS_AGENT.md`
- `specs/ci-cd-pipeline_spec.md`
- `deploy/contracts/infra-crosswalk.yaml`
