# Security Operations
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains the canonical operator-facing security surface for secret handling, auth hardening, and operational security procedures.

## Use this directory for

- security operating guidance
- auth and secret handling procedures
- operational security policy references
- incident and verification material for platform security operations

## Key documents

- [`ALLOWED_ACTIONS_POLICY.md`](ALLOWED_ACTIONS_POLICY.md) for operator action boundaries
- [`AUTH_HARDENING_SPEC.md`](AUTH_HARDENING_SPEC.md) for the enforced auth hardening contract
- [`AUTH_CHANGE_CHECKLIST.md`](AUTH_CHANGE_CHECKLIST.md) for auth rollout and change sequencing
- [`ENTERPRISE_SSO_GUIDE.md`](ENTERPRISE_SSO_GUIDE.md) for enterprise SSO operational setup
- [`SECRET_SCANNING.md`](SECRET_SCANNING.md) for secret scanning expectations and posture
- [`SECRETS_SNAPSHOT.md`](SECRETS_SNAPSHOT.md) for current secret inventory snapshots
- [`MOBILE_SECRETS_MANAGEMENT.md`](MOBILE_SECRETS_MANAGEMENT.md) for mobile secret handling
- [`in-cluster-auth-verification.md`](in-cluster-auth-verification.md) for runtime auth verification inside the cluster

## Supporting artifacts

- [`AUTH_PR_SECTION.md`](AUTH_PR_SECTION.md) for the standard auth review section used in PRs
- [`README_WARNING_SNIPPET.md`](README_WARNING_SNIPPET.md) for the shared warning language used in security-facing docs

## Do not use this directory for

- general product security specs, which belong in `specs/**`
- historical audit reports, which belong in `docs/status/**` or archive surfaces
- superseded compatibility copies in losing roots
