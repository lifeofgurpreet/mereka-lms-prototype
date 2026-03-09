---
title: Control Planes
owner: Platform Team
status: canonical
last_reviewed: 2026-03-09
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
audience:
  - Engineering Team
summary: Defines the control planes that own configuration, deployment, and platform behavior across the system.
tags:
  - architecture
  - platform.control-plane
governs:
  - platform.control-plane
  - platform.repo-boundary
  - build.gitops-promotion
---
# Control Planes

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
