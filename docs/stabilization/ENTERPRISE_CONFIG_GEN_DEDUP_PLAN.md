# Stabilization: Enterprise Config-Gen Dedup Plan

> Priority 2 — reduce duplicated inline config-gen logic across enterprise services.

## Problem

Five enterprise service deployments (+ 2 workers) each contain a nearly-identical inline
Python config-gen init container. When a conceptual fix is needed (JWT auth, CSRF, OAuth2),
it must be applied identically to 6-7 files. Drift is inevitable and has caused real failures.

## Current Duplication Map

### Files (all in bbi-infrastructure)

| File | Service | Config Output |
|------|---------|--------------|
| `base/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml` | enterprise-access | `/config/enterprise_access.yml` |
| `base/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml` | enterprise-catalog | `/config/enterprise_catalog.yml` |
| `base/deploy/k8s/base/apps/enterprise/enterprise-subsidy-deployment.yaml` | enterprise-subsidy | `/config/enterprise_subsidy.yml` |
| `base/deploy/k8s/base/apps/enterprise/license-manager-deployment.yaml` | license-manager | `/config/license_manager.yml` |
| `base/deploy/k8s/base/apps/enterprise/workers/enterprise-access-worker-deployment.yaml` | access worker | `/config/enterprise_access.yml` |
| `base/deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml` | catalog worker | `/config/enterprise_catalog.yml` |

### Duplicated Blocks (Identical Across All Services)

| Block | Lines | Identical? |
|-------|-------|-----------|
| `import os, yaml; import json as _json` | 2 | Yes |
| `lms_root = os.environ.get(...)` | 1 | Yes |
| JWT private key derivation (7 lines) | 7 | Yes |
| `JWT_AUTH` dict (14 lines) | 14 | Yes |
| `SOCIAL_AUTH_EDX_OAUTH2_*` (4 keys) | 4 | Yes |
| `BACKEND_SERVICE_EDX_OAUTH2_*` (2 keys) | 2 | Yes |
| `LMS_BASE_URL`, `LMS_URL`, `LMS_ROOT_URL` | 3 | Yes |
| `OAUTH2_PROVIDER_URL` | 1 | Yes |
| YAML dump + file write | 3 | Yes |
| **Total duplicated** | **~40 lines per service** | |

### Intentionally Different (Per-Service)

| Key | enterprise-access | enterprise-catalog | enterprise-subsidy | license-manager |
|-----|------------------|-------------------|-------------------|-----------------|
| DB_NAME | enterprise_access | enterprise_catalog | enterprise_subsidy | license_manager |
| DB_USER | enterprise_access | enterprise_catalog | enterprise_subsidy | license_manager |
| SECRET_KEY source | `ENTERPRISE_ACCESS_SECRET_KEY` | `ENTERPRISE_CATALOG_SECRET_KEY` | `ENTERPRISE_SUBSIDY_SECRET_KEY` | `LICENSE_MANAGER_SECRET_KEY` |
| DB password secret | `MYSQL_ENTERPRISE_ACCESS_PASSWORD` | `MYSQL_ENTERPRISE_CATALOG_PASSWORD` | `MYSQL_ENTERPRISE_SUBSIDY_PASSWORD` | `MYSQL_LICENSE_MANAGER_PASSWORD` |
| Cache Redis DB | 12 | 8 | 10 | 11 |
| Celery Redis DB | 13 | 9 | N/A | N/A |
| Service port | 18270 | 8160 | 18280 | 18170 |
| Config file path | `/config/enterprise_access.yml` | `/config/enterprise_catalog.yml` | `/config/enterprise_subsidy.yml` | `/config/license_manager.yml` |
| OAuth2 key | enterprise-access-key | enterprise-catalog-key | enterprise-subsidy-key | license-manager-key |
| KEY_PREFIX | enterprise_access | enterprise_catalog | enterprise_subsidy | license_manager |
| CSRF_COOKIE_NAME | `csrftoken` (shared with LMS) | not set | not set | not set |
| CSRF_TRUSTED_ORIGINS | `[lms, learner.lms, admin.lms]` | not set | not set | not set |
| Cross-service URLs | catalog, subsidy, license-mgr | discovery, catalog-self | N/A | N/A |
| Has Celery? | Yes | Yes | No | No |

## Target Architecture

### Option A: Shared ConfigMap with base config (Recommended)

Create a shared `enterprise-common-config.py` ConfigMap that generates the common block.
Each service's init container sources it and adds service-specific overrides.

```
enterprise-common-config (ConfigMap)
  └── common-config-gen.py
        ├── JWT_AUTH block
        ├── JWK derivation
        ├── OAuth2 defaults
        ├── LMS URL defaults
        └── helper functions

Per-service init container:
  1. exec(open('/shared/common-config-gen.py').read())
  2. override service-specific keys
  3. write to /config/<service>.yml
```

**Pros**: Single source of truth for JWT/OAuth2/CSRF. Per-service overrides stay local.
**Cons**: Shared ConfigMap adds one dependency. Init container args change.

### Option B: Kustomize configMapGenerator with envsubst

Generate a shared YAML template with `${VAR}` placeholders, substitute per-service.

**Pros**: No Python in init containers.
**Cons**: Kustomize envsubst is limited. Complex nested structures (JWT_AUTH) are hard to template.

### Option C: Helm chart or jsonnet

**Rejected**: Too much tooling change for the current state.

## Implementation Plan (Option A)

### Phase 1: Extract shared config-gen helper

Create: `bbi-infrastructure/apps/mereka-lms/base/deploy/k8s/base/apps/enterprise/shared/enterprise-config-gen.py`

```python
"""Shared enterprise service config generator.

Usage in init container args:
    exec(open('/shared/enterprise-config-gen.py').read())
    config = generate_enterprise_config(
        service_name='enterprise_access',
        db_name='enterprise_access',
        cache_db=12,
        celery_db=13,  # None if no celery
        service_port=18270,
        extra_config={
            'CSRF_COOKIE_NAME': 'csrftoken',
            'CSRF_TRUSTED_ORIGINS': [...],
            'LICENSE_MANAGER_URL': 'http://license-manager:18170',
        },
    )
    write_config(config, '/config/enterprise_access.yml')
```

### Phase 2: Create shared ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: enterprise-config-gen-shared
data:
  enterprise-config-gen.py: |
    # ~60 lines: common JWT, OAuth2, DB, cache, celery generation
```

### Phase 3: Refactor each service init container

Before (per service, ~80 lines inline Python):
```yaml
args:
  - |
    import os, yaml
    # ... 80 lines of duplicated logic ...
```

After (per service, ~15 lines):
```yaml
args:
  - |
    exec(open('/shared/enterprise-config-gen.py').read())
    config = generate_enterprise_config(
        service_name='enterprise_access',
        db_name='enterprise_access',
        cache_db=12,
        celery_db=13,
        extra_config={
            'CSRF_COOKIE_NAME': 'csrftoken',
            'CSRF_TRUSTED_ORIGINS': derive_csrf_origins(lms_root),
        },
    )
    write_config(config, '/config/enterprise_access.yml')
```

### Phase 4: Add test for config-gen output

Create a test that:
1. Runs the shared generator with known inputs
2. Verifies JWT_AUTH block is correct
3. Verifies CSRF settings match expectations
4. Verifies no service accidentally omits critical keys

### Phase 5: Verify and deploy

1. Render with `kubectl kustomize` — verify all configs generate correctly
2. Deploy to dev — verify all enterprise services start
3. Compare generated YAML against current baseline

## First PR

**Scope**: Create the shared `enterprise-config-gen.py` with tests. Do NOT refactor deployments yet.

**Risk**: ZERO — adding a new file, no existing files changed.

**Follow-up PRs**:
1. Refactor enterprise-access to use shared helper (prove pattern)
2. Refactor remaining services (one PR per service or batch)
3. Remove inline duplication

## Acceptance Criteria

- [ ] One edit fixes a conceptual issue (JWT, CSRF, OAuth2) across all enterprise services
- [ ] Enterprise service config differences are intentional, not accidental
- [ ] Shared helper has tests that catch regressions
- [ ] Each service's init container is <20 lines (vs current ~80)
