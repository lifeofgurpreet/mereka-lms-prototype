# Implementation Order

Generated from `depends_on` frontmatter in spec files.

## Tier 0

| Spec | ACs | Title |
|------|-----|-------|
| cross-cutting-requirements_spec.md | 12 | Cross-Cutting Requirements |
| repository-structure_spec.md | 12 | Repository Structure Specification |

## Tier 1

| Spec | ACs | Title |
|------|-----|-------|
| secrets-management_spec.md | 18 | Secrets Management Specification |
| tutor-configuration_spec.md | 10 | Tutor Configuration Lifecycle |

## Tier 2

| Spec | ACs | Title |
|------|-----|-------|
| k8s-deployment_spec.md | 32 | Kubernetes Deployment Specification |
| mongodb-atlas-integration_spec.md | 9 | MongoDB Atlas Integration |
| multi-site-domains_spec.md | 9 | Multi-Site Domain Configuration |
| tutor-configuration-resilience_spec.md | 12 | Tutor Configuration Resilience and Patch Automation |

## Tier 3

| Spec | ACs | Title |
|------|-----|-------|
| analytics-pipeline_spec.md | 8 | Analytics Pipeline (Aspects/Panorama) |
| branding-system_spec.md | 10 | Branding System |
| ci-cd-pipeline_spec.md | 39 | CI/CD Pipeline Specification |
| data-migrations-kajabi-mct_spec.md | 44 | Data Migrations: Kajabi & MCT Legacy Systems |
| disaster-recovery-business-continuity_spec.md | 22 | Disaster Recovery & Business Continuity |
| forum-service-migration_spec.md | 22 | Forum Service Migration: Ruby cs_comments_service to Python openedx-forum |
| observability-stack_spec.md | 8 | Observability Stack (Prometheus/Tempo/Loki) |
| platform-middleware-custom-apps_spec.md | 20 | Platform Middleware and Custom Apps |
| video-pipeline-delivery_spec.md | 25 | Video Pipeline & Delivery System |

## Tier 4

| Spec | ACs | Title |
|------|-----|-------|
| design-tokens-system_spec.md | 12 | Design Tokens System |
| multi-tenancy-architecture_spec.md | 28 | Multi-Tenancy Architecture |
| slo-sla-service-level-management_spec.md | 23 | SLO/SLA Definitions & Service Level Management |
| oep48-brand-package_spec.md | 37 | OEP-48 Brand Package *(depends on: branding-system, design-tokens-system)* |
| mfe-plugin-slots_spec.md | 29 | MFE Plugin Slots Activation *(depends on: branding-system, oep48-brand-package)* |
| frontend-accessibility_spec.md | 26 | Frontend Accessibility *(depends on: branding-system, mfe-plugin-slots)* |
| studio-customization_spec.md | 28 | Studio Customization *(depends on: branding-system, multi-tenancy-architecture)* |
| frontend-performance-budgets_spec.md | 30 | Frontend Performance Budgets *(depends on: branding-system, oep48-brand-package)* |

## Tier 5

| Spec | ACs | Title |
|------|-----|-------|
| auth-sso-enterprise_spec.md | 45 | Authentication & SSO Enterprise Integration |
| paragon-design-tokens-migration_spec.md | 41 | Paragon Design Tokens Migration *(depends on: oep48-brand-package, design-tokens-system)* |

## Tier 6

| Spec | ACs | Title |
|------|-----|-------|
| enterprise-microservices_spec.md | 36 | Enterprise Microservices Deployment |

## Tier 7

| Spec | ACs | Title |
|------|-----|-------|
| advanced-assessment-xqueue_spec.md | 39 | Advanced Assessment & XQueue Integration (Non-Proctored) |
| badges-credentials-enterprise_spec.md | 32 | Badges & Credentials Enterprise Integration |
| content-libraries-v2_spec.md | 33 | Content Libraries v2 Management & Enterprise Usage |
| ecommerce-purchase-gateway_spec.md | 33 | Ecommerce Purchase Gateway (Stripe -> Open edX Integration) |
| email-notifications-pipeline_spec.md | 45 | Email & Notifications Pipeline |
| proposals/mobile-apps-enterprise_spec.md | 37 | Mobile Apps (iOS + Android) Enterprise Deployment |

## Tier 8

| Spec | ACs | Title |
|------|-----|-------|
| proposals/external-registration-hubspot_spec.md | 26 | External Registration via HubSpot |
| proposals/proctoring-integration_spec.md | 38 | Proctoring Integration for Enterprise Open edX |

## Tier 9

| Spec | ACs | Title |
|------|-----|-------|
| data-privacy-gdpr-compliance_spec.md | 30 | Data Privacy & GDPR Compliance |

**Total**: 40 specs, 960+ ACs, 10 tiers *(6 new frontend specs added 2026-02-27)*
