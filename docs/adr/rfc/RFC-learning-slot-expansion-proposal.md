---
id: RFC-learning-slot-expansion-proposal
title: Learning Slot Expansion Proposal
decision_status: proposed
decision_type: domain
rollout_state: planned
owner: platform-team
created: '2026-03-07'
last_reviewed: '2026-03-10'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on:
- ADR-021
read_next:
- ADR-035
governs:
- frontend.runtime-composition
does_not_govern:
- current accepted frontend slot law
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

# Learning MFE Slot Expansion Proposal

**Date**: 2026-02-28  
**Owner**: Mereka frontend team  
**Scope**: `frontend-app-learning` upstream slot requests for course-grid and page-shell surfaces.

## Problem

Phase C/D reduced brittle wildcard selectors and moved major shell branding to supported plugin slots.  
Learning pages still require CSS-only overrides for several structural surfaces because current Ulmo slots are narrow (`course_outline_sidebar.v1`, `progress_certificate_status.v1`) and do not expose course-grid/card shell insertion points.

## Current State

Available learning slots in our runtime today:

- `org.openedx.frontend.learning.course_outline_sidebar.v1`
- `org.openedx.frontend.learning.progress_certificate_status.v1`

These cover sidebar and certificate status content, but not:

- course-grid container shell
- individual course card chrome/actions
- top-level learning page banner/hero shell

## Proposed Upstream Slots

Proposed new slots (naming aligned with existing `org.openedx.frontend.learning.*.v1` convention):

1. `org.openedx.frontend.learning.course_grid.v1`
2. `org.openedx.frontend.learning.course_card.v1`
3. `org.openedx.frontend.learning.course_card_action.v1`
4. `org.openedx.frontend.learning.page_header.v1`

## Why These Four

1. They target the highest-fragility surfaces still styled by CSS structure selectors.
2. They allow plugin-first customization without DOM-coupled wildcard selectors.
3. They mirror patterns already proven in learner-dashboard slots (`course_card`, `course_card_action`, `dashboard_header`).

## Acceptance Shape (Upstream)

For each slot:

1. Exposed via stable `PluginSlot` in `frontend-app-learning`.
2. Receives enough props/context for non-destructive insertion (`Insert`) and optional replacement (`Replace`) where appropriate.
3. Documented in Open edX operator docs with slot name, location, and expected render contract.

## Local Migration Plan Once Upstream Lands

1. Register new slots in `infrastructure/tutor/plugins/mereka_lms.py` under `PLUGIN_SLOTS`.
2. Move remaining learning-specific shell overrides from `mereka.scss` into slot-owned React components.
3. Remove deprecated CSS selector exceptions tied to learning wrappers.
4. Enforce via `scripts/qa/verify-selector-to-slot-migration.sh` and migration register checks.

## Tracking

- Inventory baseline: `docs/reference/architecture/FPF_PLUGIN_SLOT_REGISTRY.md`
- Migration tracker: `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
- Dead selector context: `docs/reference/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md`

## Scope

This proposal governs the decision boundary described by RFC-learning-slot-expansion-proposal.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- No dedicated automated fitness function is registered yet; use linked specs and runbooks for review.
