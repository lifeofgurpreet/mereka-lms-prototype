# Multi-Tenancy Explained

This page explains the tenant model without re-stating every environment or URL by hand.

## What A Tenant Means Here

A tenant is a site-level learning surface with its own learner entry point and branding expectations, running on top of a platform that can still share underlying services.

Use the generated references for the current facts:

- [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)

## How Tenant Maps To Site, Domain, Branding, And Course Availability

- site and domain mapping determine which learner and Studio surfaces are valid
- branding and site configuration determine how that surface is presented
- course visibility can be constrained by tenant-scoped site configuration such as organization filters
- some tenants have production-only surfaces today, which is why the generated topology distinguishes lane presence explicitly

## What Is Shared

Treat these as shared unless the generated topology proves otherwise:

- shared platform services such as Authentik
- shared service layers like Discovery, Credentials, and Forum where the topology reference marks them shared
- the underlying Open edX runtime packaging and deployment machinery

## What Is Isolated

Treat these as tenant-specific unless the generated topology marks them unresolved:

- learner-facing domain
- branding and site-level presentation
- user base and tenant-facing access boundaries
- some Studio and MFE surfaces

## Global Versus Tenant Override

- global defaults live in platform and contract-controlled layers
- tenant overrides live in site configuration and branding layers
- generated references explain what is currently proven, including unresolved conflicts

If a requested override is not already represented by the generated topology, treat it as a change request, not as an assumed capability.

## Where Tenancy Truth Lives

- generated tenant and access truth: [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- generated shared-versus-tenant topology truth: [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)
- multi-site operational rules in this repo: [Multi-Site Guide](../admin/MULTI_SITE_GUIDE.md)
- cross-repo lane and service contracts consumed by the generated topology

## Metadata

- Canonical internal sources: `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/reference/operations/USER_FACING_URLS.md`
- Official external references: `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/sites/configure_site.html`, `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/changing_appearance/theming/enable_themes.html`
- Owner: Platform Team
- Last reviewed: 2026-03-10
- Applies to: tenant admins, operators, and engineers reasoning about tenant boundaries
- What is tenant-specific: domains, branding, user access boundaries, some Studio and MFE surfaces
- What is platform-wide: shared services, Tutor/runtime packaging, release-control contracts, generated governance surfaces
- What must be escalated: unresolved tenant topology fields, any request to add or remove tenant surfaces, and any change that crosses from site configuration into infrastructure or contract ownership
