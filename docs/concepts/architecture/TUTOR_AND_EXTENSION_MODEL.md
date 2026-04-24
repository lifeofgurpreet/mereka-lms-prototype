---
title: Tutor And Extension Model
owner: Platform Team
status: canonical
last_reviewed: 2026-03-09
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
audience:
  - Engineering Team
summary: Defines how Tutor, plugins, and extension points are used to customize and operate the platform safely.
tags:
  - architecture
  - platform.control-plane
governs:
  - platform.extension-model
  - build.version-pin
  - build.image.registry
---
# Tutor And Extension Model

## Governs

- platform.extension-model
- build.version-pin
- build.image.registry

## Non-goals

- feature-level UI decisions
- product release sequencing

## Standard

- `requirements-tutor.txt` is the canonical Tutor version pin.
- Simple platform customization MUST prefer Tutor plugins and hooks over ad hoc Dockerfile surgery.
- Local proof-of-work happens before CI-heavy builds.
- Internal plugin and package compatibility must be declared rather than implied.

## Fitness Functions

- `scripts/qa/verify-tutor-version-pin.sh`
- `scripts/qa/verify-tutor-config-safety.sh`

## Source ADRs

- `ADR-019`
- `ADR-021`
- `ADR-040`
