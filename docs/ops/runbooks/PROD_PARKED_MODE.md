# Production Parked Mode

Production (GKE `bbi-k8-cluster`, namespace `mereka-lms`) is
intentionally parked at zero replicas to control cost. This is
NOT an outage.

## Expected State When Parked

### Workloads at 0 replicas (normal)

- lms, cms, lms-worker, cms-worker
- mfe
- mysql, redis
- elasticsearch, meilisearch
- discovery, credentials, notes, xqueue, smtp
- enterprise-access, enterprise-catalog, enterprise-subsidy
- enterprise-access-worker, enterprise-catalog-worker
- enterprise-admin-portal, enterprise-learner-portal
- license-manager
- argocd-* (controller, repo-server, redis, dex, notifications)

### Workloads that remain running (intentional)

- caddy (1 replica) — serves maintenance/redirect page
- preview-redirect (1 replica) — redirects preview URLs
- payments-gateway (2-3 replicas) — active payment processing
- postgresql-payments (1 replica) — payments database
- mux-delivery-monitor (1 replica) — video delivery monitoring

### Expected public behavior when parked

- `https://academyv2.mereka.io` → 502 or maintenance page (Caddy)
- `https://studio.academyv2.mereka.io` → 502 or redirect
- `https://apps.academyv2.mereka.io/*` → 502

These are NOT incidents. They are the expected behavior of a
parked production environment.

## Wake-Up Procedure

Scale core workloads to serving state:

```bash
# Context
kubectl config use-context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

# Scale core
kubectl scale deployment lms cms mfe redis -n mereka-lms --replicas=1
kubectl scale deployment lms-worker cms-worker -n mereka-lms --replicas=1

# Wait for readiness
kubectl rollout status deployment/lms deployment/cms deployment/mfe \
  -n mereka-lms --timeout=300s

# Verify endpoints
kubectl get endpoints lms cms mfe caddy -n mereka-lms
```

MySQL is Cloud SQL (managed) — no scaling needed.

## Park Procedure

```bash
kubectl scale deployment lms cms mfe lms-worker cms-worker \
  redis elasticsearch meilisearch discovery credentials notes \
  xqueue smtp -n mereka-lms --replicas=0
```

## Verification Script

Use `scripts/qa/verify-prod-parked-state.sh` to confirm the
parked state is intentional and not degraded.

The current post-build runtime workflow uses this verifier instead of browser
E2E while production remains parked. See `config/runtime-proof-policy.env` and
`docs/ops/runbooks/POST_DEPLOY_GATE.md`.

## Reactivation Hand-off

When production is intentionally reactivated, the browser/runtime proof lane
switches from the parked-state verifier to:

- `scripts/tenants/verify-prod-runtime-proof.sh`
- `config/runtime-proof/prod.synthetic-proof-fixtures.yaml`
- `config/smoke-account-registry.yaml`

Do not reactivate production by copying the dev fixture story. The production
runtime-proof verifier and the production fixture manifest are the canonical
non-dev proof surfaces.
