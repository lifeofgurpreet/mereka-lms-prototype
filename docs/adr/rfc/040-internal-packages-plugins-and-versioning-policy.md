---
title: Internal Packages, Plugins, and Versioning Policy
proposal_state: proposed
owner: platform-team
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes internal package, plugin, and versioning rules for platform extensions.
tags:
- plugins
- packages
- versioning
decision_type: domain
decision_status: proposed
governs:
- platform.extension-model
- build.version-pin
id: ADR-040
rollout_state: planned
supersedes: []
amends:
- ADR-006
- ADR-021
depends_on:
- ADR-028
- ADR-030
read_next: []
does_not_govern:
- external-upstream-release-timelines
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

# ADR-040: Internal Packages, Plugins, and Versioning Policy

## Decision
Internal packages and plugins MUST follow semantic versioning with explicit compatibility contracts and deprecation windows.

## Scope
Governs internal package/plugin lifecycle and version compatibility policy.

## Non-goals
Upstream version policy outside team control.

## Context
Custom plugin/package growth without semver policy increases breakage risk across releases.

## Decision details
- Breaking changes require major version increments.
- Plugin compatibility with Tutor/Open edX release lines MUST be declared.

## Invariants
No internal package release without declared compatibility range.

## Verification
Version contract checks in CI and release workflow.

## Failure modes
Silent consumer breakage due to untracked breaking changes.

## Consequences
Predictable maintenance and upgrade posture.

## Alternatives considered
Unversioned internal artifacts and implicit compatibility.
