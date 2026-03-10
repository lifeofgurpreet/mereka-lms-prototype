---
title: Authorization Model
owner: Auth Platform
status: canonical
last_reviewed: 2026-03-09
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
audience:
  - Engineering Team
summary: Defines role, permission, and authorization boundaries across platform and tenant surfaces.
tags:
  - architecture
  - auth.authorization.roles
governs:
  - auth.authorization.roles
  - tenant.isolation
---
# Authorization Model

## Governs

- auth.authorization.roles
- tenant.isolation

## Non-goals

- identity-provider protocol choice
- login UX copy

## Standard

- Platform-admin, tenant-admin, staff, and learner scopes must be explicit.
- Cross-tenant administrative access must be minimal and auditable.
- Role mappings must not implicitly escalate across tenant boundaries.

## Fitness Functions

- `scripts/qa/verify-org-role-ownership.sh both`

## Source ADRs

- `ADR-041`
- `ADR-033`
- `ADR-029`
