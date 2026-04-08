---
id: ADR-021
title: Open edX / Tutor Deployment Methodology
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: engineering
created: '2026-03-03'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next:
- ADR-028
- ADR-029
- ADR-030
governs:
- platform.deployment-methodology
- build.tutor.plugin
- build.release-line
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-repo-structure.sh
- scripts/qa/verify-tutor-config-safety.sh
expiry_date: null
removal_condition: null
---
<!-- markdownlint-disable -->

# ADR-021: Open edX / Tutor Deployment Methodology

## Context

Open edX delivery work crosses release-line selection, Tutor customization, frontend injection, CI validation, and heavy image build operations. Without a single methodology ADR, agents re-open settled implementation lanes and create conflicting build practices.

## Decision

Open edX / Tutor delivery for Mereka LMS MUST follow one fixed methodology:

1. Ulmo on Tutor 21.x is the active release line until ADR-019 changes it.
2. Supported Tutor hooks are the default customization mechanism; ad hoc Dockerfile surgery is legacy debt, not an approved pattern.
3. MFE customization uses plugin slots plus design-token branding, not direct source-tree edits.
4. Any maintained `edx-platform` fork MUST track the latest supported release tag, not moving upstream branches.
5. Local preflight proves a change before CI; CI validates, it does not discover the design.
6. Heavy image builds belong on the approved ARC runner lane with registry-backed cache.

## Scope

This ADR governs release-line, customization, and build-methodology rules for Open edX / Tutor work in this repository.

## Non-goals

- Replacing ADR-006, ADR-019, or ADR-029 for their narrower decision boundaries.
- Defining tenant-specific branding content or feature behavior.
- Serving as a runbook for every build or upgrade operation.

## Decision details

- The canonical Tutor version pin lives in `requirements-tutor.txt`; repo workflows and scripts MUST align to it.
- `infrastructure/tutor/plugins/mereka_lms.py` is the supported home for hook-based customization.
- `infrastructure/tutor/apply-patches.sh` remains only for post-render file work that Tutor hooks cannot express.
- MFE customization MUST use Tutor plugin hooks, `tutormfe.hooks.PLUGIN_SLOTS`, and `@edx/brand`-style tokenized branding patterns.
- `scripts/ci/preflight-check.sh` is the minimum local proof before pushing build-affecting changes.
- CI image builds MUST target the approved ARC heavy-runner lane and use registry-backed BuildKit cache.

## Invariants

- Release-line decisions and customization-mechanism decisions MUST NOT be conflated.
- New customization work MUST prefer supported Tutor extension paths over template or Dockerfile surgery.
- `main` MUST remain a validation target, not a debugging lane.

## Verification

- `scripts/qa/verify-repo-structure.sh`
- `scripts/qa/verify-tutor-config-safety.sh`
- `scripts/ci/preflight-check.sh`

## Failure modes

- Mixed Tutor release tooling creates incompatible render behavior.
- Build logic drifts into CI-only experimentation instead of local proof.
- New frontend customization bypasses plugin hooks and recreates ungoverned patch debt.

## Consequences

- Agents get a single methodology boundary before touching Open edX delivery work.
- Legacy patch debt is explicitly constrained instead of normalized.
- The platform keeps a consistent proof model: local preflight first, CI second.

## Alternatives considered

- Let each ADR or runbook define its own build method.
  - Rejected: produces inconsistent delivery behavior and recurrent tool-lane drift.
- Use CI as the primary debugging surface.
  - Rejected: slow feedback loop and poor signal quality.
- Treat old Dockerfile surgery as an equal customization path.
  - Rejected: conflicts with ADR-006 and keeps upgrade debt alive.
