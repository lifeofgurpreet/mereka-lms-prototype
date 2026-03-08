# Architecture Documentation
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This directory is the canonical architecture narrative and living-standards root for Mereka LMS.

## Authority boundary

- Living architecture standards live here.
- ADRs in `docs/adr/` remain the decision ledger.
- Legacy `docs/architecture/**` is transitional compatibility surface during Wave 2 and MUST NOT be treated as the winning authority root.
- Operator procedure lives in `docs/ops/**`.
- Proof lives in `docs/evidence/**`.
- Active status lives in `docs/status/**`.

## Start here

1. [ARCHITECTURE_CHARTER.md](ARCHITECTURE_CHARTER.md)
2. [DOCUMENTATION_AUTHORITY_RESOLVER.md](DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [DOCS_SPECS_CONTRACT.md](../../guides/standards/DOCS_SPECS_CONTRACT.md)
4. the domain-specific standard, overview, or RFC you actually need
5. proposal queue: [../../adr/rfc/](../../adr/rfc/)

## Infrastructure Architecture

- **[DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md)** - Database strategy (MySQL, MongoDB Atlas, Redis)
- **[MONGODB_ATLAS_MIGRATION.md](../../../reports/2025/closures/MONGODB_ATLAS_MIGRATION.md)** - Historical MongoDB Atlas migration closeout
- **[MULTISITE_ANALYSIS.md](../../../reports/2025/audits/MULTISITE_ANALYSIS.md)** - Historical multi-site audit
- **[ADR-025-deployment-boundary.md](../../architecture/rfc/ADR-025-deployment-boundary.md)** - Transitional RFC location retained under the legacy architecture root during Wave 2

## Open edX Service Overviews

- **[badges-credentials-overview.md](../../../specs/archive/badges-credentials-overview.md)** - Digital badges and credentials system
- **[content-libraries-overview.md](../../architecture/overviews/content-libraries-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2
- **[enterprise-services-overview.md](../../architecture/overviews/enterprise-services-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2
- **[multi-tenancy-overview.md](../../architecture/overviews/multi-tenancy-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2
- **[notification-pipeline-overview.md](../../architecture/overviews/notification-pipeline-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2
- **[proctoring-architecture-overview.md](../../architecture/overviews/proctoring-architecture-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2
- **[purchase-gateway-overview.md](../../architecture/overviews/purchase-gateway-overview.md)** - Transitional overview retained under the legacy architecture root during Wave 2

## Related Documentation

- **Architecture Decision Records:** [../../adr/](../../adr/) - Formal ADR ledger
- **Operator Docs:** [../../ops/](../../ops/) - Canonical operator runbooks and quick references
- **Specifications:** [../../../specs/](../../../specs/) - Normative intended behavior
- **Legacy architecture compatibility root:** [../../architecture/README.md](../../architecture/README.md)

## Contributing

When adding new architecture documentation:
1. Add a descriptive filename.
2. Include metadata with audience, owner, last verified date, and status.
3. Update this README when discoverability changes.
4. Route the content to the right artifact type before writing:
   - living architecture standard in this directory
   - ADR for accepted decision history
   - RFC for undecided design
   - ops/evidence/status if the content is procedure, proof, or reporting
