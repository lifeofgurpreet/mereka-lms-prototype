# Documentation Index
_Audience: Everyone • Owner: Infra Team • Last verified: 2026-03-09 • Status: canonical_

This is the front door to the Mereka LMS documentation system.

Use it to answer two questions quickly:

1. Which root is authoritative for this kind of document?
2. What is the minimum reading set for the task in front of me?

## Start here

Read these three docs before following any older path:

1. [Architecture Charter](concepts/architecture/ARCHITECTURE_CHARTER.md)
2. [Documentation Authority Resolver](concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
3. [Docs/Specs Contract](guides/standards/DOCS_SPECS_CONTRACT.md)

If those three do not answer your routing question, stop and resolve the route before reading more. Most documentation confusion in this repo has historically come from reading the wrong root, not from missing words.

For the current decision-grade review and agent hot path, also read:

4. [Wave 9 Closeout](meta/docs-program/WAVE9_CLOSEOUT.md)
5. [Wave 9 Review Handoff](meta/docs-program/WAVE9_REVIEW_HANDOFF.md)

## Root authority map

| Root | Role | Status |
| --- | --- | --- |
| [docs/concepts/architecture/](concepts/architecture/README.md) | Living architecture standards and narrative | Canonical |
| [docs/adr/](adr/README.md) | Decision ledger and RFC queue | Canonical |
| [docs/ops/](ops/README.md) | Operator procedures, quick references, monitoring, security, CI/CD | Canonical |
| [docs/guides/](guides/README.md) | Human guidance, onboarding, admin, standards | Canonical |
| [docs/reference/](reference/README.md) | Reference material for architecture, operations, and migrations | Canonical |
| [docs/policies/](policies/README.md) | Current policy surfaces for architecture and operations | Canonical |
| [docs/meta/](meta/README.md) | Docs-program internals, templates, standing orders, and transition ledgers | Canonical |
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

Do not load the whole corpus by default. Read the hot path first, then add one domain root only if the task actually touches it.

## Quick route by task

| If you need to... | Start here | Then read |
| --- | --- | --- |
| get the right platform URL or handbook path by role | [guides/platform/PLATFORM_START_HERE.md](guides/platform/PLATFORM_START_HERE.md) | [reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md](reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md) and [reference/platform/TEAM_TOPOLOGY_REFERENCE.md](reference/platform/TEAM_TOPOLOGY_REFERENCE.md) |
| understand active architecture rules | [concepts/architecture/README.md](concepts/architecture/README.md) | charter, resolver, the specific standard for that domain |
| run or debug the platform | [ops/README.md](ops/README.md) | quickref, then the relevant runbook/monitoring/security subroot |
| change contributor-facing guidance | [guides/README.md](guides/README.md) | onboarding, admin, integrations, or standards |
| check a policy or operational boundary | [policies/README.md](policies/README.md) | architecture or operations policy subroot |
| look up runtime/reference detail | [reference/README.md](reference/README.md) | architecture, operations, or migrations reference |
| verify what was proven | [evidence/INDEX.md](evidence/INDEX.md) | the owning evidence subroot |
| understand current rollout or readiness state | [status/INDEX.md](status/INDEX.md) | active, migrations, readiness, weekly, or incidents |
| inspect decision history or open proposals | [adr/README.md](adr/README.md) | accepted ADRs, RFC queue, or templates |
| change intended behavior | `specs/**` | then return to docs only for explanation/runbooks/evidence |

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

- [Platform Handbook](guides/platform/PLATFORM_START_HERE.md)
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

If a reader would need tribal knowledge to find the document after your change, the change is incomplete.

Primary contributor references:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [Documentation Standards](guides/standards/DOCUMENTATION_STANDARDS.md)
- [Docs Remediation Plan and Tracker](DOCS_REMEDIATION_PLAN_AND_TRACKER.md)

## Generated and derived surfaces

These are derived outputs, not hand-authored authority:

- [docs/catalog.json](catalog.json)
- [generated/catalogs/docs-catalog.json](../generated/catalogs/docs-catalog.json)
- [generated/catalogs/README.md](../generated/catalogs/README.md)
- ADR generated surfaces under `generated/adr-bundles/`, `generated/decision-maps/`, and `generated/graphs/`

If a generated file conflicts with a canonical source doc, fix the source and regenerate.

## What not to do

- Do not treat `docs/operations/**`, `docs/runbooks/**`, `docs/onboarding/**`, `docs/branding/**`, or `docs/architecture/**` as living authority.
- Do not put proof artifacts under random roots when `docs/evidence/**` owns them.
- Do not put active reporting under archive or top-level `reports/**` when `docs/status/**` owns it.
- Do not hand-edit generated catalog or testmap outputs and call that authoritative.
