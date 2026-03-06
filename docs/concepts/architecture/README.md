# Architecture Documentation

_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-06 • Status: canonical_

This directory contains architectural overviews and design documentation for the Mereka Academy Open edX platform.

## Infrastructure Architecture

- **[DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md)** - Database strategy (MySQL, MongoDB Atlas, Redis)
- **[MONGODB_ATLAS_MIGRATION.md](MONGODB_ATLAS_MIGRATION.md)** - MongoDB Atlas migration details
- **[MULTISITE_ANALYSIS.md](MULTISITE_ANALYSIS.md)** - Multi-site architecture analysis

## Open edX Service Overviews

- **[badges-credentials-overview.md](../../../specs/archive/badges-credentials-overview.md)** - Digital badges and credentials system
- **[content-libraries-overview.md](content-libraries-overview.md)** - Content libraries architecture
- **[enterprise-services-overview.md](enterprise-services-overview.md)** - Enterprise features and integrations
- **[multi-tenancy-overview.md](multi-tenancy-overview.md)** - Multi-tenancy implementation
- **[notification-pipeline-overview.md](notification-pipeline-overview.md)** - Notification and messaging pipeline
- **[proctoring-architecture-overview.md](proctoring-architecture-overview.md)** - Exam proctoring system
- **[purchase-gateway-overview.md](purchase-gateway-overview.md)** - E-commerce and payment processing

## Related Documentation

- **Architecture Decision Records:** [../adr/](../../adr/) - Formal ADRs for major architectural decisions
- **Operations Guides:** [../operations/](../../operations/) - Operational runbooks and guides
- **Specifications:** [../../specs/](../../../specs/) - Machine-checkable specifications

## Contributing

When adding new architecture documentation:
1. Add a descriptive filename (e.g., `service-name-overview.md`)
2. Include metadata line with audience, owner, and last verified date
3. Update this README to link to your new document
4. Consider whether an ADR is needed for the decision
