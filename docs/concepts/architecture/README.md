---
title: Architecture Documentation
owner: Platform Team
status: canonical
last_reviewed: 2026-03-10
last_verified: 2026-03-10
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
summary: Canonical front door for living architecture standards and real architecture overviews.
tags:
  - architecture
  - standards
  - navigation
governs:
  - platform.control-plane
  - docs.policy
---

# Architecture Documentation

This directory is the canonical living architecture root for Mereka LMS.

## Use this root for

Come here when you need:
- current architecture law,
- the architecture hot path,
- or real architecture overviews that still belong in a concepts root.

## Authority boundary

- Living architecture standards live here.
- ADRs in `docs/adr/` remain the decision ledger.
- Contracts, inventories, and audit-style reference live in `docs/reference/**`.
- Policy lives in `docs/policies/**`.
- Operator procedure lives in `docs/ops/**`.
- Proof lives in `docs/evidence/**`.
- Active status lives in `docs/status/**`.

## Hot path

1. [ARCHITECTURE_CHARTER.md](ARCHITECTURE_CHARTER.md)
2. [DOCUMENTATION_AUTHORITY_RESOLVER.md](DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [CONTROL_PLANES.md](CONTROL_PLANES.md)
4. [IDENTITY_DOMAIN_BOUNDARIES.md](IDENTITY_DOMAIN_BOUNDARIES.md)
5. [TENANT_LIFECYCLE.md](TENANT_LIFECYCLE.md)
6. [TUTOR_AND_EXTENSION_MODEL.md](TUTOR_AND_EXTENSION_MODEL.md)
7. [RELEASE_ROLLOUT_AND_REMOVAL.md](RELEASE_ROLLOUT_AND_REMOVAL.md)
8. [DATA_GOVERNANCE.md](DATA_GOVERNANCE.md)
9. [AUTHORIZATION_MODEL.md](AUTHORIZATION_MODEL.md)

## Living standards

- [ARCHITECTURE_CHARTER.md](ARCHITECTURE_CHARTER.md)
- [DOCUMENTATION_AUTHORITY_RESOLVER.md](DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [CONTROL_PLANES.md](CONTROL_PLANES.md)
- [IDENTITY_DOMAIN_BOUNDARIES.md](IDENTITY_DOMAIN_BOUNDARIES.md)
- [TENANT_LIFECYCLE.md](TENANT_LIFECYCLE.md)
- [TUTOR_AND_EXTENSION_MODEL.md](TUTOR_AND_EXTENSION_MODEL.md)
- [RELEASE_ROLLOUT_AND_REMOVAL.md](RELEASE_ROLLOUT_AND_REMOVAL.md)
- [DATA_GOVERNANCE.md](DATA_GOVERNANCE.md)
- [AUTHORIZATION_MODEL.md](AUTHORIZATION_MODEL.md)

## Living overviews

- [content-libraries-overview.md](content-libraries-overview.md)
- [enterprise-services-overview.md](enterprise-services-overview.md)
- [multi-tenancy-overview.md](multi-tenancy-overview.md)
- [notification-pipeline-overview.md](notification-pipeline-overview.md)
- [proctoring-architecture-overview.md](proctoring-architecture-overview.md)
- [purchase-gateway-overview.md](purchase-gateway-overview.md)

## Related roots

- [`../../reference/architecture/README.md`](../../reference/architecture/README.md) for contracts, inventories, and audit-style reference
- [`../../policies/architecture/README.md`](../../policies/architecture/README.md) for enforceable policy surfaces
- [`../../adr/README.md`](../../adr/README.md) for decisions and historical law
- [`../../adr/rfc/README.md`](../../adr/rfc/README.md) for proposals

## What does not belong here

Do not use this root for:
- redirect stubs,
- operator procedures that belong in `docs/ops/**`,
- active proof that belongs in `docs/evidence/**`,
- active status that belongs in `docs/status/**`,
- or accepted decision history that belongs in `docs/adr/**`.

## Contributing

When adding architecture documentation:
1. Put living standards and real overviews here.
2. Put contracts, inventories, and audits in `docs/reference/**`.
3. Put rules in `docs/policies/**`.
4. Put decisions and proposals in `docs/adr/**`.
