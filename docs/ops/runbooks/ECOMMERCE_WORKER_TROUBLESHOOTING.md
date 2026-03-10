# Ecommerce-Worker CrashLoopBackOff — Troubleshooting Runbook

_Audience: Platform Engineering • Last updated: 2026-02-24_

> **Context**: The legacy Oscar ecommerce-worker (`overhangio/openedx-ecommerce-worker:19.0.0`)
> is being replaced by the custom Purchase Gateway (`services/purchase-gateway/`).
> A CrashLoopBackOff on nonprod is **expected** when Oscar is not fully configured.
> See the [Decision Tree](#decision-tree) below before spending time debugging Oscar.

---

## Quick Diagnosis (5 commands)

```bash
# 1. Pod status
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=ecommerce-worker

# 2. Restart count
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=ecommerce-worker \
  -o custom-columns="NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount"

# 3. Last 50 log lines (before latest crash)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=ecommerce-worker \
  --tail=50 --previous

# 4. Is Purchase Gateway running instead?
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway

# 5. Run the verification script
scripts/qa/verify-ecommerce-worker-health.sh --online
```

---

## Decision Tree

```
Is ecommerce-worker crashing?
│
├── YES
│   │
│   ├── Is ENABLE_GATEWAY_FULFILLMENT=true in services/purchase-gateway/k8s/deployment.yaml?
│   │   ├── YES → Purchase Gateway is the active payment path.
│   │   │         Scale ecommerce-worker to 0: see "Scale to Zero" below.
│   │   └── NO  → Oscar is still the active payment path (dark launch).
│   │             Continue to "Known Crash Causes" below.
│   │
│   └── Is this the nonprod / kind cluster?
│       ├── YES → CrashLoop is expected (Oscar not fully configured on nonprod).
│       │         Either accept the crash (Gateway will replace it) or
│       │         scale to 0 to clean up noise: see "Scale to Zero" below.
│       └── NO  → This is production. Escalate. Debug immediately using
│                 "Known Crash Causes" below.
│
└── NO → No action needed.
```

---

## Known Crash Causes

### 1. Missing or empty `JWT_SECRET_KEY_ECOMMERCE`

**Symptom**: Worker starts then immediately exits with `ImproperlyConfigured` or
`django.core.exceptions.ImproperlyConfigured: JWT_SECRET_KEY`.

**Cause**: The ExternalSecret `openedx-secrets` does not have a valid value for
`JWT_SECRET_KEY_ECOMMERCE`.

**Diagnosis**:
```bash
kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.JWT_SECRET_KEY_ECOMMERCE}' | base64 -d | wc -c
# Should be non-zero
```

**Fix**: Ensure `MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE` exists in GCP Secret Manager
(`bbi-k8` project) and that the ExternalSecret has synced:
```bash
kubectl describe externalsecret openedx-secrets -n mereka-lms | grep -A5 "Status"
```

---

### 2. Celery cannot connect to Redis broker

**Symptom**: Worker logs show `redis.exceptions.ConnectionError` or
`kombu.exceptions.OperationalError`.

**Cause**: The `BROKER_URL = "redis://redis:6379"` in the worker settings points to
the `redis` Kubernetes service. If Redis is not running or the service is missing,
the worker cannot start.

**Diagnosis**:
```bash
# Check Redis pod
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=redis

# Check Redis service
kubectl get svc redis -n mereka-lms

# Test connectivity from the worker pod (if it's briefly running)
kubectl exec -n mereka-lms deploy/ecommerce-worker -- \
  python -c "import redis; r=redis.Redis(host='redis',port=6379); print(r.ping())"
```

**Fix**: Ensure the Redis Deployment and Service are running. On nonprod (kind),
Redis should be present as a Tutor-managed service.

---

### 3. `WORKER_CONFIGURATION_MODULE` not set or wrong value

**Symptom**: Worker exits with `ModuleNotFoundError` or `ImportError`.

**Cause**: The env var `WORKER_CONFIGURATION_MODULE` is absent or points to a
module path that doesn't exist in the mounted ConfigMap volume.

**Expected value**:
```
WORKER_CONFIGURATION_MODULE=ecommerce_worker.configuration.tutor.production
```

**Diagnosis**:
```bash
kubectl exec -n mereka-lms deploy/ecommerce-worker -- \
  printenv WORKER_CONFIGURATION_MODULE
# Should print: ecommerce_worker.configuration.tutor.production

# Verify the settings file is mounted
kubectl exec -n mereka-lms deploy/ecommerce-worker -- \
  ls /openedx/ecommerce_worker/ecommerce_worker/configuration/tutor/
# Should include production.py
```

**Fix**: Verify the `ecommerce-worker-settings` ConfigMap is present and correctly
mounted in the Deployment manifest (`deploy/k8s/base/apps/purchase-gateway/deployment.yaml`).

---

### 4. `C_FORCE_ROOT` not set

**Symptom**: Worker refuses to start with message:
`Running a worker with superuser privileges when the worker accepts messages serialized with pickle is a very bad idea!`

**Cause**: Celery refuses to run as root (container uid=0) unless `C_FORCE_ROOT=1`
is explicitly set.

**Fix**: Verify the Deployment has `C_FORCE_ROOT: "1"` in its env block. If it's
missing, add it to `deploy/k8s/base/apps/purchase-gateway/deployment.yaml` under the ecommerce-worker
container spec.

---

### 5. Missing MySQL password (database connection for dispatched tasks)

**Symptom**: Worker starts but tasks immediately fail with `django.db.OperationalError`
or `Access denied for user 'ecommerce'`.

**Cause**: The `MYSQL_ECOMMERCE_PASSWORD` env var is not injected into the worker
pod (it is injected into the main ecommerce pod but not always wired to the worker).

**Diagnosis**:
```bash
kubectl exec -n mereka-lms deploy/ecommerce-worker -- \
  printenv MYSQL_ECOMMERCE_PASSWORD 2>/dev/null && echo "SET" || echo "MISSING"
```

**Fix**: Ensure the `openedx-secrets` Secret (which maps `MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD`)
is referenced in the worker's `envFrom` or `env` block. The main ecommerce
Deployment already references this secret; replicate the wiring to `ecommerce-worker`.

---

### 6. Oscar not configured on nonprod (expected crash)

**Symptom**: Worker crashes during Django setup with errors related to missing
SiteConfiguration, Partner records, or OAuth2 clients.

**Cause**: Oscar requires database seed data (SiteConfiguration, Partner, OAuth2
client records) that is only present in production. On nonprod/kind clusters, these
rows are not seeded by default.

**This is the expected state on nonprod.** The crash is benign.

**Options**:
- Accept the crash and wait for Purchase Gateway to replace Oscar (preferred).
- Scale ecommerce-worker to 0 replicas to suppress noise (see below).

---

## Scale to Zero (suppress nonprod noise)

If Oscar is not needed on a cluster, scale the worker to 0 replicas to silence
the CrashLoop alerts:

```bash
kubectl scale deploy/ecommerce-worker -n mereka-lms --replicas=0

# Verify
kubectl get deploy ecommerce-worker -n mereka-lms
# READY should show 0/0
```

To restore:
```bash
kubectl scale deploy/ecommerce-worker -n mereka-lms --replicas=1
```

> **Note**: This is a live-cluster change. If the cluster is managed by ArgoCD,
> it will be reverted on the next sync unless the manifest's `replicas` field is
> also updated in git. To make it permanent, patch
> `deploy/k8s/overlays/local/kustomization.yaml` (or the relevant overlay) to
> add a replica count patch.

---

## Relationship to T029 — Oscar Deprecation

The ecommerce-worker is part of the Oscar ecommerce stack being deprecated via
**ADR-018** (`docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`).

The full decommission sequence (tracked as T029 / AC-027, AC-028) is:

1. **Now**: Purchase Gateway is dark-launched (`ENABLE_GATEWAY_FULFILLMENT=false`).
   Oscar (including ecommerce-worker) remains active on production.

2. **Cutover** (T029): Set `ENABLE_GATEWAY_FULFILLMENT=true`. New purchases route
   to the Gateway. In-flight Oscar orders drain.

3. **Decommission** (AC-028): Remove ecommerce Deployment, ecommerce-worker
   Deployment, Service, Caddy routing block, DNS records, and OAuth2 clients.
   Run `scripts/infra/decommission-legacy-ecommerce.sh` (to be created in T029).

4. **Cleanup**: Remove Oscar secrets from ExternalSecrets and GCP Secret Manager.

Until step 3 is complete, ecommerce-worker must remain in the manifests even if
scaled to 0. Do not delete the Deployment manifest before the decommission task
is executed.

---

## Verification

```bash
# Offline manifest checks
scripts/qa/verify-ecommerce-worker-health.sh --offline

# Live cluster checks
scripts/qa/verify-ecommerce-worker-health.sh --online

# Full Oscar deprecation audit (checks all Oscar references across the repo)
scripts/qa/verify-oscar-deprecation.sh

# Ecommerce OAuth + site config (requires running ecommerce pod)
scripts/qa/verify-ecommerce-config.sh
```

---

## Related Documents

| Document | Description |
|----------|-------------|
| `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` | ADR: Oscar deprecation decision |
| `docs/reference/operations/ECOMMERCE_DEPRECATION_INVENTORY.md` | All Oscar references + disposition |
| `docs/ops/runbooks/ECOMMERCE_OAUTH_TROUBLESHOOTING.md` | OAuth2 client setup for Oscar |
| `services/purchase-gateway/` | Replacement service (FastAPI + PostgreSQL + Stripe) |
| `specs/ecommerce-purchase-gateway_spec.md` | Full spec (AC-027 through AC-033) |
