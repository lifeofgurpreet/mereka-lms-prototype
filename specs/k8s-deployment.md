# Kubernetes Deployment Specification

**Status**: Active
**Last Updated**: 2026-02-03

## Overview

This spec defines Kubernetes deployment requirements for Mereka LMS.

## MUST Requirements

### Namespace
- All OpenEdX resources MUST be in `mereka-lms` namespace

### Secrets Integration
- LMS and CMS deployments MUST have envFrom referencing:
  - openedx-secrets
  - database-secrets

```yaml
envFrom:
  - secretRef:
      name: openedx-secrets
  - secretRef:
      name: database-secrets
```

### ExternalSecrets
- MUST use ExternalSecrets (not static Secret manifests)
- MUST reference `gcp-secret-manager` ClusterSecretStore
- MUST have `refreshInterval: 1h`

### Environment Overlays
Two overlays are supported (local dev + production):
| Overlay | Replicas | Image Tag |
|---------|----------|-----------|
| local | 1 each | latest |
| production | 2 LMS, 1 CMS | production |

## Verification

```bash
# Check namespace
kubectl get ns mereka-lms  # MUST exist

# Check ExternalSecrets
kubectl get externalsecrets -n mereka-lms -o wide
# MUST show: openedx-secrets, database-secrets with STATUS=SecretSynced

# Check deployments have envFrom
kubectl get deploy lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].envFrom}'
# MUST include secretRef to openedx-secrets and database-secrets

# Validate overlays
kubectl kustomize deploy/k8s/overlays/local --enable-helm 2>/dev/null | head -20
# MUST not error
```
