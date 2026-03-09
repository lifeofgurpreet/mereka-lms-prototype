# Tutor And Extension Model
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

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
