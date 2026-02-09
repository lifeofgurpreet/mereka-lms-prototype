---
title: Kubernetes Deployment Specification
type: feature_spec
status: draft
owner: engineering
vehicle: talent_platform
last_updated: '2026-02-08'
---
# Kubernetes Deployment Specification

**Status**: Active
**Last Updated**: 2026-02-06

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

**Dev (kind) note:** `gcp-secret-manager` in kind uses a service account key
stored in `external-secrets/gcp-secret-manager` (key `key.json`). Run
`scripts/infra/bootstrap-kind-secrets.sh` to create/update the secret and
apply the local ClusterSecretStore override.

### Environment Overlays
Two overlays are supported (local dev + production):
| Overlay | Replicas | Image Tag |
|---------|----------|-----------|
| local | 1 each | latest |
| production | 2 LMS, 1 CMS | production |

### Observability Baseline (Production)
- MUST keep these synthetic auth/TLS CronJobs present in `mereka-lms`:
  - `auth-verify-prod`
  - `cert-verify-prod`
- MUST keep Velero verification CronJobs present in `velero`:
  - `backup-verification`
  - `restore-test`
- MUST keep monitoring-as-code JSON under `infrastructure/monitoring/` valid and deployable.
- MUST run `scripts/qa/audit-observability.sh --mode local` after monitoring template edits.

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

# Observability template integrity
./scripts/qa/audit-observability.sh --mode local
# MUST return OK
```


## Scope

_Defines the boundaries of this specification._

## Non-goals

_Explicitly out of scope for this specification._

## Requirements

- This section requires review to add MUST/SHOULD/MAY requirements.

## Acceptance Criteria

- [ ] AC-001: Acceptance criteria to be defined.

## Edge Cases

_Edge cases to be documented._

## Observability

_Logging, metrics, and alerting requirements to be defined._

## Rollout & Rollback

_Rollout strategy and rollback procedures to be defined._

## Open Questions

_No open questions at this time._
