# Mereka LMS

Mereka Academy's learning management system — an Open edX platform managed
with [Tutor](https://docs.tutor.edly.io/), deployed to RKE2 Kubernetes
clusters, and integrated with the broader BBI / Mereka platform (enterprise
B2B stack, custom commerce gateway, tenant-aware frontends).

## What lives here

This TechDocs site surfaces the most useful parts of the `docs/` directory
inside Backstage. The raw source is [on GitHub](https://github.com/Biji-Biji-Initiative/mereka-lms/tree/main/docs).

Start at:

- **[Quick Start](guides/onboarding/QUICK_START_LOCAL.md)** — fastest path to a running local LMS.
- **[Local Setup](guides/onboarding/LOCAL_SETUP.md)** — full Tutor bring-up with MFE build + branding.
- **[Devcontainer Guide](guides/onboarding/DEVCONTAINER_GUIDE.md)** — containerised dev environment.
- **<a href="./ops/runbooks/TROUBLESHOOTING/">Troubleshooting runbook</a>** &mdash; site-down / service-mismatch diagnostic flow.

## Architecture at a glance

- **LMS + Studio**: Open edX 21.x (Ulmo), wrapped by Tutor 21.0.
- **MFEs**: React micro-frontends served by a Caddy bundle.
- **Enterprise stack**: B2B access control, catalog, subsidy, license-manager, plus admin and learner portal MFEs.
- **Commerce**: custom FastAPI `purchase-gateway` (Stripe) + HubSpot/Kajabi webhooks.
- **Data plane**: MySQL 8, Redis, MongoDB Atlas (managed), Elasticsearch, Meilisearch, SMTP relay.

Key Architecture Decision Records:

- [ADR-021: Open edX + Tutor methodology](adr/021-openedx-tutor-methodology.md)
- [ADR-024: Multi-tenancy model](adr/024-multi-tenancy-true-tenants.md)
- [ADR-028: Platform sources of truth and control planes](adr/028-platform-sources-of-truth-and-control-planes.md)
- [ADR-033: Tenant lifecycle contract](adr/033-tenant-lifecycle-contract.md)

## Live environments

| Env | LMS | Studio | MFE |
|---|---|---|---|
| Dev | <https://academyv2.mereka.dev> | — | — |
| Prod | <https://academyv2.mereka.io> | <https://studio.academyv2.mereka.io> | <https://apps.academyv2.mereka.io> |

## Related services in the catalog

- `mereka-lms-app` (this entity) — the LMS web service
- `mereka-lms-cms` — Studio (course authoring)
- `mereka-lms-mfe` — MFE bundle
- `mereka-lms-enterprise-*` — B2B stack
- `mereka-lms-purchase-gateway` — commerce

See the [Components](https://backstage.mereka.io/catalog?filters%5Bkind%5D=component&filters%5Buser%5D=all) tab for the full system map.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Most docs changes also trigger a
rebuild of this site through the `techdocs-publish` GitHub Actions workflow.
