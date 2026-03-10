---
id: ADR-006
title: Tutor Plugin-Based Configuration Resilience
decision_status: accepted
decision_type: domain
rollout_state: active
owner: engineering
created: '2026-02-10'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next:
- ADR-021
- ADR-028
governs:
- build.tutor.plugin
- platform.config-rendering
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
---

# ADR-006: Tutor Plugin-Based Configuration with Three-Layer Defense

## Context

Tutor regenerates configuration artifacts destructively. Hand-applied post-render edits are therefore unsafe as the primary mechanism for platform-critical configuration.

Mereka LMS still needs two categories of change:
- render-time configuration changes that Tutor can express through supported hooks
- post-render file-system work such as asset sync or directory population that Tutor hooks do not express directly

The architecture must keep those categories separate and verifiable.

## Decision

Tutor configuration resilience MUST use a three-layer model:

1. Tutor plugin hooks are the default path for render-time configuration.
2. `infrastructure/tutor/apply-patches.sh` is reserved for post-render file-system work only.
3. Verification MUST run both locally and in CI so unpatched outputs cannot become accepted repo truth.

## Alternatives Considered

- Wrapper-only patch application.
  - Rejected: direct `tutor config save` calls bypass wrappers.
- Plugin-only patching.
  - Rejected: file-copy and asset sync work still exists outside hookable render steps.
- Tutor fork as primary configuration mechanism.
  - Rejected: raises maintenance cost and weakens alignment with supported Tutor extension paths.

## Scope

This ADR governs how configuration changes are applied and verified in the Tutor render pipeline.

## Non-goals

- Defining the release-line policy; see ADR-019 and ADR-021.
- Defining frontend branding policy; see ADR-014 and ADR-021.
- Replacing runbooks or implementation evidence for specific patch sets.

## Decision details

- Render-time changes MUST be implemented through `infrastructure/tutor/plugins/mereka_lms.py` when Tutor exposes a supported hook.
- `infrastructure/tutor/apply-patches.sh` MUST NOT become a second configuration law surface; it is limited to file-system and asset operations that occur after render.
- Patch verification MUST validate rendered output rather than trusting that a command was invoked.
- New patch work MUST declare which layer owns it and how that ownership is verified.

## Invariants

- `tutor config save` MUST remain safe to run without losing governed configuration.
- A rendered configuration artifact MUST have one declared mutation path, not competing hook-and-script truth.
- Verification MUST fail when required patch outcomes are absent from rendered outputs.

## Verification

- `scripts/infra/verify-tutor-patches.sh`
- `specs/tutor-configuration-resilience_spec.md`
- `specs/tutor-configuration_spec.md`

## Failure modes

- Required configuration lives only in post-hoc script edits and disappears on re-render.
- Plugin hook drift after Tutor upgrade leaves rendered output incomplete.
- File-system patch work expands back into config-authoring work and recreates split-brain truth.

## Consequences

- Render-time configuration law becomes explicit and reviewable.
- Tutor upgrades still require hook audits, but failures become detectable instead of silent.
- File-system patch work remains necessary, so discipline is required to keep that lane narrow.
