---
id: RFC-claim-based-role-sync
title: Claim-Based Role Sync
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
- ADR-029
read_next:
- ADR-041
governs:
- auth.role-mapping
does_not_govern:
- current accepted authorization policy
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

# RFC: Claim-Based Role Sync (Authentik -> Open edX)
_Audience: Infra/Security • Owner: Platform • Status: Draft • Last updated: 2026-02-06_

## Summary

Today, Authentik provides **authentication** (OIDC) and the Open edX services provide **authorization**
(`is_staff`, `is_superuser`, `CourseCreator`, etc.). Permissions do **not** sync from Authentik by default.

We currently enforce platform-admin authorization via:
- explicit allowlist (`MEREKA_PLATFORM_ADMIN_EMAILS`)
- idempotent scripts (see `docs/reference/operations/AUTH_AND_PERMISSIONS.md`)

This RFC explores an optional future: **granting/maintaining roles based on OIDC claims** minted by Authentik.

## Problem

As we add more services and more humans, a static allowlist can become:
- operationally annoying (more places to update)
- easy to forget during new service onboarding

We want a system that can:
- reduce manual work
- be auditable and safe
- avoid privilege escalation

## Current State (Recommended Baseline)

Keep Authentik as the source of truth for identity only. Keep authorization local:
- Platform admins enforced per-service (LMS/CMS/Discovery/Credentials/Ecommerce).
- Authentik admin is separate (Gurpreet only).
- Verification is deterministic via:
  - `./scripts/qa/verify-auth-hardening.sh`
  - `./scripts/qa/audit-auth-access.sh`

## Proposal (Optional)

1. In Authentik, mint a stable claim, e.g.:
   - `groups: ["platform-admin"]`
2. In each service, add a pipeline/middleware step that:
   - reads the claim from the OIDC token (or userinfo)
   - grants/revokes `is_staff`/`is_superuser` (and CMS `CourseCreator`) based on it

## Threat Model / Risks

Main risk is **privilege escalation** if any of these are wrong:
- The service accepts tokens not meant for it (bad `audience` / client mismatch).
- Tokens can be replayed or forged due to weak signing key practices.
- “Admin claims” can be minted too broadly (wrong group mapping).
- Different services interpret claims differently (inconsistent mapping).

Mitigations (non-negotiable if implementing):
- Validate token `aud`, `iss`, `exp`, and signature strictly per service.
- Prefer a single “platform-admin” claim that is small and explicit.
- Log and audit every elevation (who, when, where, why).
- Keep a hard backstop allowlist (break-glass) during rollout.

## Rollout Plan (If We Ever Implement)

1. Start read-only:
   - log what would be granted, but do not change DB flags
2. Enable for dev only
3. Enable for prod for a small allowlist of emails
4. Remove old pathways only after a long period with no drift

## Backout Plan

1. Turn off claim-based elevation in all services
2. Re-run:
   - `./scripts/infra/ensure-platform-admins.sh`
3. Verify:
   - `./scripts/qa/verify-auth-hardening.sh`

## Recommendation

Do **not** implement claim-based role sync until we have a clear need (more admins, more services),
and we have time for a proper security review. The current allowlist+verification approach is
intentionally tight and low-risk.

## Scope

This proposal governs the decision boundary described by RFC-claim-based-role-sync.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- No dedicated automated fitness function is registered yet; use linked specs and runbooks for review.
