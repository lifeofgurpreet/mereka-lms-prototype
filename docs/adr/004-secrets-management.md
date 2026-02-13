# ADR-004: Secrets Management

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

<!-- Last verified: 2026-02-13 -->

## Context

Open edX requires numerous secrets:
- Database passwords
- SECRET_KEYs for Django
- JWT signing keys
- OAuth2 client secrets
- API keys

Previously, secrets were hardcoded in configuration files (security risk).

## Decision

We implement a **layered secrets management** approach:
1. **Infisical** as the source of truth for all secrets
2. **Kubernetes Secrets** for runtime injection
3. **Environment variables** in application code

## Consequences

### Positive
- No hardcoded secrets in git repository
- Centralized secret management
- Audit trail for secret access
- Easy secret rotation
- Separation of concerns (infra team manages secrets, app uses env vars)

### Negative
- Additional operational complexity
- Requires Infisical infrastructure
- Secrets sync process needed

## Alternatives Considered

### GCP Secret Manager Only
- Native GKE integration via CSI driver
- **Rejected because**: Want single source of truth across all environments

### HashiCorp Vault
- Industry standard, highly capable
- **Rejected because**: Operational overhead, cost for managed service

### Sealed Secrets
- GitOps-friendly encrypted secrets
- **Rejected because**: Rotation requires git commits, less flexible

## Implementation Notes

- Secrets defined in `deploy/k8s/base/secrets/`
- Each service has unique JWT secret (no sharing)
- Python settings use `os.environ.get()` pattern
- See: `/home/gurpreet/projects/secrets-management/` for Infisical setup
