# Admin Guides
_Audience: Operators and administrators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This directory contains canonical administrator guidance for operating and validating the platform through supported admin surfaces.

## Start here

- Need to get into the platform safely:
  - start with [`ADMIN_LOGIN_GUIDE.md`](ADMIN_LOGIN_GUIDE.md)
- Need tenant or multisite administration:
  - start with [`MULTI_SITE_GUIDE.md`](MULTI_SITE_GUIDE.md)
- Need cluster or secrets posture from an admin workflow:
  - start with [`K8S_OPERATIONS_GUIDE.md`](K8S_OPERATIONS_GUIDE.md) or [`SECRETS_MANAGEMENT_GUIDE.md`](SECRETS_MANAGEMENT_GUIDE.md)
- Need observability or data-store validation from the admin side:
  - start with [`OBSERVABILITY_GUIDE.md`](OBSERVABILITY_GUIDE.md) or [`MONGODB_ATLAS_GUIDE.md`](MONGODB_ATLAS_GUIDE.md)

## Use this directory for

- admin-facing operational guides
- platform configuration and access guides for administrators
- run-throughs for core admin workflows

## Do not use this directory for

- low-level operator runbooks, which belong in `docs/ops/**`
- stable architecture front doors, which belong in `docs/architecture/**`
- docs-program plans, scorecards, or closure notes that belong in `docs/meta/**`, `docs/status/**`, or archive surfaces

## Core admin guides

- [`ADMIN_LOGIN_GUIDE.md`](ADMIN_LOGIN_GUIDE.md)
- [`MULTI_SITE_GUIDE.md`](MULTI_SITE_GUIDE.md)
- [`K8S_OPERATIONS_GUIDE.md`](K8S_OPERATIONS_GUIDE.md)
- [`SECRETS_MANAGEMENT_GUIDE.md`](SECRETS_MANAGEMENT_GUIDE.md)
- [`OBSERVABILITY_GUIDE.md`](OBSERVABILITY_GUIDE.md)
- [`MONGODB_ATLAS_GUIDE.md`](MONGODB_ATLAS_GUIDE.md)
- [`ENTERPRISE_SERVICES_GUIDE.md`](ENTERPRISE_SERVICES_GUIDE.md)

## When not to use this directory

If the reader needs:
- a low-level runbook, send them to `docs/ops/**`
- stable architecture front doors, send them to `docs/architecture/**` first
- active proof, send them to `docs/evidence/**`
- active status, send them to `docs/status/**`
- docs-program planning or remediation tracking, send them to `docs/meta/docs-program/**`
