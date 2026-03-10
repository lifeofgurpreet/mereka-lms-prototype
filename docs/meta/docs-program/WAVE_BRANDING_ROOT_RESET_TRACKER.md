---
title: Wave Branding Root Reset Tracker
owner: Platform Team
status: canonical
last_verified: 2026-03-10
canonical_root: docs/meta/docs-program
doc_class: tracker
summary: Packet tracker for retiring docs/branding as a living documentation root.
tags:
  - docs
  - branding
  - root-reset
audience: Contributors
---

# Wave Branding Root Reset Tracker

## Objective

Retire `docs/branding/**` as a living documentation root. The canonical branding guidance already lives under `docs/guides/branding/**`, so this wave removes the duplicate compatibility tree and leaves only a tombstone README.

## Canonical owner after reset

- Canonical living branding root: `docs/guides/branding/**`
- Transitional compatibility root to retire: `docs/branding/**`

## File classification

### Delete after rewriting refs

- `docs/branding/BRANDING.md`
- `docs/branding/BRANDING_GUARDRAILS.md`
- `docs/branding/BRANDING_INCIDENT_TEMPLATE.md`
- `docs/branding/BRANDING_OPERATING_MODEL.md`
- `docs/branding/BRANDING_OPERATOR_GUIDE.md`
- `docs/branding/BRANDING_PLAN.md`
- `docs/branding/BRANDING_ROADMAP.md`
- `docs/branding/BRANDING_VERIFICATION_CHECKLIST.md`
- `docs/branding/FOOTER_V2_TO_LMS_MAPPING.md`
- `docs/branding/MULTI_TENANT_BRANDING_OPS.md`
- `docs/branding/PARAGON_TOKEN_ALIGNMENT.md`
- `docs/branding/PLUGIN_MIGRATION_SURVEY.md`
- `docs/branding/TENANT_BRANDING_CONTRACT.md`
- `docs/branding/TENANT_BRAND_PACK_SCHEMA.md`
- `docs/branding/TENANT_CONFIG_HANDOFF.md`
- `docs/branding/TENANT_ONBOARDING_PLAYBOOK.md`
- `docs/branding/VISUAL_PARITY_CHECKPOINTS.md`
- `docs/branding/audit-2026-02-05/README.md`

### Retain

- `docs/branding/README.md`
  - Rewrite as a tombstone-only redirect to `docs/guides/branding/**`.

## Reference pressure found in Packet A

Active repo references still pointed at `docs/branding/**` from:

- canonical docs front doors and standards
- architecture routing docs
- specs and plan docs
- one infrastructure tenant README
- docs-policy tooling that tracks transitional roots

## Sidecar decision

No canonical sidecar or generator-owned data was found under `docs/branding/**`. The root is duplicate prose only.

## Packet record

### Packet A

- Scope: classify `docs/branding/**`, prove canonical target root, record ref sweep.
- Validation: repo search for `docs/branding/` and duplicate-tree comparison against `docs/guides/branding/**`.
- Result: proceed with full retirement, not wrapper refresh.

### Packet B

- Scope: rewrite active internal refs to `docs/guides/branding/**`.

### Packet C

- Scope: delete duplicate branding wrapper tree and keep tombstone README only.

### Packet D

- Scope: add no-regrowth guard and wire it into docs policy checks.

### Packet E

- Scope: closeout and review handoff.
