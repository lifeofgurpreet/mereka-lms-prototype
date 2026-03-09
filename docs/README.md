# Documentation Index
_Audience: Everyone • Owner: Infra Team • Last verified: 2026-03-09 • Status: canonical_

This is the front door to the Mereka LMS documentation system.

Use it to answer two questions quickly:

1. Which root is authoritative for this kind of document?
2. What is the minimum reading set for the task in front of me?

## Start here

Read these first before following any older path:

1. [Architecture Charter](concepts/architecture/ARCHITECTURE_CHARTER.md)
2. [Documentation Authority Resolver](concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [Docs/Specs Contract](guides/standards/DOCS_SPECS_CONTRACT.md)

## Root authority map

| Root | Role | Status |
| --- | --- | --- |
| [docs/concepts/architecture/](concepts/architecture/README.md) | Living architecture standards and narrative | Canonical |
| [docs/adr/](adr/README.md) | Decision ledger and RFC queue | Canonical |
| [docs/ops/](ops/README.md) | Operator procedures, quick references, monitoring, security, CI/CD | Canonical |
| [docs/guides/](guides/README.md) | Human guidance, onboarding, admin, standards | Canonical |
| [docs/reference/](reference/README.md) | Reference material for architecture, operations, and migrations | Canonical |
| [docs/policies/](policies/README.md) | Current policy surfaces for architecture and operations | Canonical |
| [docs/evidence/](evidence/INDEX.md) | Active proof bundles | Canonical |
| [docs/status/](status/INDEX.md) | Active reporting and status tracking | Canonical |
| `docs/operations/**` | Legacy compatibility surface | Transitional |
| `docs/onboarding/**` | Legacy compatibility surface | Transitional |
| `docs/branding/**` | Legacy compatibility surface | Transitional |
| `docs/runbooks/**` | Legacy compatibility surface | Transitional |
| `docs/architecture/**` | Legacy compatibility surface | Transitional |
| `docs/archive/**` | Retained history only | Cold |

## Hot path reading set

If you are starting a new task, use this reading order:

1. [Architecture Charter](concepts/architecture/ARCHITECTURE_CHARTER.md)
2. [Documentation Authority Resolver](concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [Docs/Specs Contract](guides/standards/DOCS_SPECS_CONTRACT.md)
4. [Control Planes](concepts/architecture/CONTROL_PLANES.md)
5. [Identity and Domain Boundaries](concepts/architecture/IDENTITY_DOMAIN_BOUNDARIES.md)
6. [Tenant Lifecycle](concepts/architecture/TENANT_LIFECYCLE.md)
7. [Release, Rollout, and Removal](concepts/architecture/RELEASE_ROLLOUT_AND_REMOVAL.md)
8. [Data Governance](concepts/architecture/DATA_GOVERNANCE.md)
9. [Authorization Model](concepts/architecture/AUTHORIZATION_MODEL.md)
10. [Operator Quick Reference](ops/quickref/README.md)
11. [Evidence Index](evidence/INDEX.md)
12. [Status Index](status/INDEX.md)

## Use the right root

### For operator work

Start in [docs/ops/](ops/README.md):

- [Quick Reference](ops/quickref/README.md)
- [Runbooks](ops/runbooks/README.md)
- [Monitoring](ops/monitoring/README.md)
- [CI/CD](ops/ci-cd/README.md)
- [Security](ops/security/README.md)

### For contributor guidance

Start in [docs/guides/](guides/README.md):

- [Onboarding](guides/onboarding/README.md)
- [Admin Guides](guides/admin/README.md)
- [Integrations](guides/integrations/README.md)
- [Standards](guides/standards/README.md)

### For reference and policy

Use:

- [Architecture Reference](reference/architecture/README.md)
- [Operations Reference](reference/operations/README.md)
- [Migrations Reference](reference/migrations/README.md)
- [Architecture Policies](policies/architecture/README.md)
- [Operations Policies](policies/operations/README.md)

### For proof and reporting

Use:

- [Evidence Index](evidence/INDEX.md)
- [Operations Evidence](evidence/operations/README.md)
- [Status Index](status/INDEX.md)
- [Active Status](status/active/README.md)
- [Migration Status](status/migrations/README.md)
- [Readiness Status](status/readiness/README.md)
- [Weekly Status](status/weekly/README.md)
- [Incident Status](status/incidents/README.md)

### For decisions and proposals

Use:

- [ADR README](adr/README.md)
- [RFC Queue](adr/rfc/README.md)
- [ADR Templates](adr/templates/README.md)

## Contributor rules

Before adding or moving docs:

1. Route the document to the correct canonical root.
2. Do not add new substantive content under transitional roots.
3. Update the relevant root README when discoverability changes.
4. Regenerate catalogs if canonical docs change.
5. Run the docs gates before opening a PR.

Primary contributor references:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [Documentation Standards](guides/standards/DOCUMENTATION_STANDARDS.md)
- [Docs Remediation Plan and Tracker](DOCS_REMEDIATION_PLAN_AND_TRACKER.md)

## Generated and derived surfaces

These are derived outputs, not hand-authored authority:

- [docs/catalog.json](catalog.json)
- [generated/catalogs/docs-catalog.json](../generated/catalogs/docs-catalog.json)
- ADR generated surfaces under `generated/adr-bundles/`, `generated/decision-maps/`, and `generated/graphs/`

If a generated file conflicts with a canonical source doc, fix the source and regenerate.
