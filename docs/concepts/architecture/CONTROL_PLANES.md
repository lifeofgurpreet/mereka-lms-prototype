# Control Planes
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

## Governs

- platform.control-plane
- platform.repo-boundary
- build.gitops-promotion

## Non-goals

- product behavior
- tenant-specific content

## Standard

- Repository truth lives in this repository.
- Runtime deployment truth lives in GitOps overlays.
- Cluster state is derived runtime, not hand-edited policy.
- Generated Tutor outputs are render artifacts, not canonical source.

## Fitness Functions

- `scripts/qa/verify-repo-structure.sh`
- `scripts/qa/verify-gitops-image-overrides.sh --check-infra`

## Source ADRs

- `ADR-028`
- `ADR-027`
