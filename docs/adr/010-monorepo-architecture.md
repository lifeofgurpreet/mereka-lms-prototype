# ADR-010: Monorepo Architecture

**Status**: Accepted
**Date**: 2026-02-10
**Deciders**: Platform Team
**Related**: [specs/repository-structure.md](../../specs/repository-structure.md)

## Context

The Mereka Academy platform includes:
- Open edX deployment infrastructure (Tutor, Kubernetes manifests)
- Custom services (purchase-gateway, entitlement-engine, analytics exporters)
- Configuration and automation scripts
- Documentation and specifications
- Mobile app (upstream source, deployment references)

We needed to decide on a repository strategy:
1. **Monorepo**: All code, infrastructure, and documentation in one repository (`mereka-lms`)
2. **Polyrepo**: Separate repositories for each custom service, infrastructure, and documentation
3. **Hybrid**: Infrastructure in one repo, custom services each in their own repos

Considerations included:
- Atomic changes across services and infrastructure
- Code review and collaboration workflow
- Build and deployment complexity
- Team size and coordination overhead
- Open edX platform integration

## Decision

We chose a **monorepo architecture** where all Mereka Academy platform code lives in the `mereka-lms` repository.

## Consequences

### Positive
- **Atomic changes**: Single PR can update service code, K8s manifests, specs, and docs
- **Simplified dependency management**: Cross-service changes don't require coordinating multiple PRs
- **Single source of truth**: All platform configuration in one place
- **Easier code review**: Reviewers see full context of changes
- **Simplified CI/CD**: One pipeline for all services and infrastructure
- **Consistent tooling**: Shared linting, testing, and formatting configs
- **Better refactoring**: IDE and search tools work across all code
- **Unified versioning**: Git SHA tags images and config together

### Negative
- **Repository size**: Grows larger over time (mitigated by `.gitignore` for build artifacts)
- **Build time**: CI must run tests for all changed services (mitigated by change detection)
- **Access control**: Cannot grant per-service permissions (not needed for current team size)
- **Clone time**: New developers download all code (acceptable with good .gitignore)

## Alternatives Considered

### Polyrepo (Separate repos for each service)
- Clear ownership boundaries
- Independent deployment cadence
- Smaller repository sizes
- **Rejected because**: Coordination overhead for cross-service changes, fragmented documentation, complex CI/CD, duplicated configuration (Dockerfile, K8s patterns, secrets)

### Hybrid (Infrastructure repo + service repos)
- Balance between monorepo and polyrepo
- Infrastructure changes don't affect service repos
- **Rejected because**: Still requires coordinating changes across repos, unclear boundary (where does a service's K8s manifest live?), fragmented specs and docs

## Implementation Notes

### Directory Structure

```
mereka-lms/
├── services/              # Custom microservices
│   ├── purchase-gateway/  # Stripe integration
│   ├── entitlement-engine/ # License management
│   └── analytics-exporter/ # HubSpot sync
├── infrastructure/        # Infrastructure-as-code
│   ├── tutor/            # Tutor patches and themes
│   ├── terraform/        # GCP resources
│   └── monitoring/       # Prometheus, Grafana configs
├── deploy/k8s/           # Kubernetes manifests
│   ├── base/
│   └── overlays/
├── scripts/              # Automation
│   ├── shared/          # Common utilities
│   ├── infra/           # Infrastructure ops
│   ├── migrations/      # Data migrations
│   └── qa/              # Testing and verification
├── specs/               # Machine-checkable specs
├── docs/                # Documentation
└── tests/               # Cross-cutting tests
```

### Custom Services Location

All custom services live under `services/` with a consistent structure:

```
services/<service-name>/
├── src/               # Source code
├── tests/             # Service-specific tests
├── Dockerfile         # Container image definition
├── requirements.txt   # Python dependencies (or package.json for Node)
├── README.md          # Service documentation
└── .env.example       # Environment variables template
```

### Mobile App

The mobile app (React Native) **source code lives upstream** in the Open edX repositories:
- `frontend-app-learner-portal-programs` (MFE)
- Future native mobile app (when implemented)

The `mereka-lms` repository contains:
- Mobile app deployment configurations
- Branding assets and theme customizations
- Build scripts for custom APK/IPA generation
- Mobile-specific documentation

**Why not in monorepo**: Open edX mobile apps are maintained upstream, we customize via patches and themes (same pattern as LMS/CMS). Forking entire mobile app would create maintenance burden.

### Build Optimization

CI/CD uses change detection to avoid building everything on every commit:

```yaml
# Example GitHub Actions change detection
- name: Detect changed services
  id: changes
  uses: dorny/paths-filter@v2
  with:
    filters: |
      purchase-gateway:
        - 'services/purchase-gateway/**'
      entitlement-engine:
        - 'services/entitlement-engine/**'
```

Only changed services rebuild images and run tests.

### Shared Code

Common utilities live in `services/shared/` and are imported by other services:

```python
# services/purchase-gateway/src/main.py
from services.shared.tenant_context import get_tenant_id
from services.shared.observability import log_event
```

Shared code changes trigger CI for all dependent services.

## Comparison to Upstream Open edX

Open edX core uses a **polyrepo** approach with separate repositories for:
- edx-platform (LMS/CMS)
- Each MFE (frontend-app-*)
- Each IDA (Independent Deployable Application)

We diverge from this pattern because:
- Mereka Academy custom services are tightly coupled to the platform
- Small team benefits from single-repo workflow
- Tutor already orchestrates upstream repos via Docker builds
- Our customizations are deployment-level, not platform-level

## Migration from Polyrepo (If Needed)

If team growth or organizational changes require polyrepo:

1. Create separate repositories for each service
2. Move `services/<service-name>/` to new repo root
3. Extract shared code to a library repository
4. Update CI/CD to coordinate across repos (GitHub Actions `workflow_run`)
5. Document cross-repo change procedure

Estimated effort: 2-3 weeks for 5-10 services

## References

- [Google's Monorepo Philosophy](https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext)
- [Monorepo vs Polyrepo Trade-offs](https://github.com/joelparkerhenderson/monorepo-vs-polyrepo)
- [Repository Structure Spec](../../specs/repository-structure.md)
- [Open edX Repository List](https://github.com/openedx)
