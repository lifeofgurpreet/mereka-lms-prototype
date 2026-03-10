# Open edX For Team Members

This page explains the platform in human terms without trying to replace the product manuals.

## What Open edX Is In This Platform

Open edX is the learning platform surface used by learners, course teams, and tenant admins. In this repo family, the main user-facing pieces are:

- LMS for learner-facing course access
- Studio for course authoring
- supporting services such as Discovery, Credentials, and Forum where the generated topology says they are shared

Use the generated references for the exact URLs:

- [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)

## What Tutor Is In This Platform

Tutor is the platform packaging and configuration layer for the Open edX runtime. In Mereka LMS it is not the tenant-administration UI. It is the operator and engineer control surface for:

- config generation and persistence
- environment rendering
- plugin and patch application
- local and Kubernetes deployment workflows

When this handbook says "platform-wide change", it usually means a Tutor, infrastructure, or contract-controlled change, not a course-team action.

## What Is Tenant-Specific

- learner domain and entry surface
- some Studio and MFE surfaces where the current generated references prove a tenant-specific URL
- branding and site configuration behavior
- course visibility filters such as `course_org_filter` when configured per site

## What Is Platform-Wide

- runtime packaging and deployment
- Tutor plugin and patch strategy
- global platform services such as Authentik
- release-control contracts and service identity
- shared services that the topology reference marks as shared across tenants

## Where Changes Actually Live

- URL and tenant access truth: [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- lane and shared-vs-tenant topology truth: [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)
- site configuration concepts and domain behavior in this repo: [Multi-Site Guide](../admin/MULTI_SITE_GUIDE.md)
- operator runtime procedures: [ops quick reference](../../ops/quickref/README.md) and [runbooks](../../ops/runbooks/README.md)
- cross-repo release and service identity contracts: platform-control-plane contracts consumed by the generated references

## What Not To Do

- Do not treat this page as authority for current URLs.
- Do not change generated references by hand.
- Do not assume a tenant-specific surface exists if the generated topology marks it unresolved.
- Do not use Tutor docs as a reason to bypass repo-specific contracts or GitOps boundaries.

## Metadata

- Canonical internal sources: `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/reference/operations/USER_FACING_URLS.md`
- Official external references: `https://docs.openedx.org/en/latest/index.html`, `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/sites/configure_site.html`, `https://docs.tutor.edly.io/local.html`, `https://docs.tutor.edly.io/tutorials/plugin.html`
- Owner: Platform Team
- Last reviewed: 2026-03-10
- Applies to: course teams, tenant admins, operators, and engineers working on Mereka LMS
- What is tenant-specific: domain mapping, branding, site configuration, course visibility scope
- What is platform-wide: Tutor configuration, runtime packaging, shared services, release-control contracts
- What must be escalated: any requested change that crosses from tenant behavior into Tutor or infrastructure ownership, or any unresolved tenant topology claim
