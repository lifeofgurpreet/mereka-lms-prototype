# Purchase Gateway K8s Operations
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

Operations guide for the Purchase Gateway service deployed in the current production lane under the `mereka-lms` namespace. The Purchase Gateway is the canonical replacement for the deprecated Oscar/ecommerce service.

Related: [Purchase Gateway Overview](../../concepts/architecture/purchase-gateway-overview.md) | `specs/ecommerce-purchase-gateway_spec.md` | [STRIPE_WEBHOOKS_SETUP.md](STRIPE_WEBHOOKS_SETUP.md)

---

## Operator Boundary

Use this runbook for the current gateway service:

- startup and rollout shape
- health checks and live traffic readiness
- secrets, routing, and pod-level troubleshooting
- manual recovery handoff into fulfillment replay, refunds, and OAuth checks

Do not treat this doc as the authority for the legacy Oscar service. Legacy
continuity belongs only where the dual-stack transition still explicitly
requires it.

For the stable system model, dark-launch boundary, and legacy cutover posture,
start with [Purchase Gateway Overview](../../concepts/architecture/purchase-gateway-overview.md).

## Architecture

### Components

| Component | K8s Resource | Port | Image |
|-----------|--------------|------|-------|
| payments-gateway | Deployment | 8080 | `ghcr.io/biji-biji-initiative/purchase-gateway:0.1.1` |
| postgresql-payments | Deployment | 5432 | `docker.io/postgres:16-alpine` |
| postgresql-payments | PVC | — | 5Gi, ReadWriteOnce |
| payments-gateway | HPA | — | minReplicas=1, maxReplicas=3, CPU=70% |
| payments-gateway-secrets | ExternalSecret | — | synced from the governed secrets bridge every 1h |

### Manifests Location

```
deploy/k8s/base/apps/purchase-gateway/
  deployment.yaml           # FastAPI app + Alembic init container
  service.yaml              # ClusterIP:8080
  hpa.yaml                  # autoscaling/v2
  external-secrets.yaml     # 6 secret bridge refs
  postgresql-deployment.yaml
  postgresql-service.yaml   # ClusterIP:5432
  postgresql-pvc.yaml       # 5Gi data volume
  servicemonitor-purchase-gateway.yaml
  kustomization.yaml
```

Referenced by `deploy/k8s/base/kustomization.yaml` through the governed base app package.

### Secrets (governed bridge: Infisical -> Secret Manager -> ExternalSecrets)

| K8s Key | GCP Secret Name |
|---------|-----------------|
| `SECRET_KEY` | `MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY` |
| `DATABASE_URL` | `MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL` |
| `STRIPE_SECRET_KEY` | `MEREKA_LMS_STRIPE_SECRET_KEY` |
| `STRIPE_WEBHOOK_SECRET` | `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY` |
| `LMS_OAUTH_CLIENT_SECRET` | `MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET` |
| `POSTGRESQL_PASSWORD` | `MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD` |

The operator flow is:
1. update the source secret in Infisical
2. sync the governed bridge into Secret Manager
3. let `ExternalSecret` refresh the Kubernetes secret
4. restart the affected workload

The current implementation still resolves through `ClusterSecretStore: gcp-secret-manager`; treat that resource name as an implementation detail, not the primary operator mental model.

### Caddy Route

All Purchase Gateway traffic enters the cluster through the LMS Caddy reverse proxy:

```
# deploy/k8s/base/apps/caddy/Caddyfile (production/dev server block)
handle /payments/* {
    uri strip_prefix /payments
    reverse_proxy payments-gateway:8080 { ... }
}
```

The `/payments` prefix is stripped before forwarding — paths map as follows:

| External URL | Internal FastAPI route |
|---|---|
| `/payments/webhooks/stripe/` | `/webhooks/stripe/` |
| `/payments/health/` | `/health/` |
| `/payments/ready/` | `/ready/` |
| `/payments/api/v1/checkout/` | `/api/v1/checkout/` |

**Stripe webhook endpoints:**

| Environment | Webhook URL |
|---|---|
| Production | `https://academyv2.mereka.io/payments/webhooks/stripe/` |
| Dev | `https://academyv2.mereka.dev/payments/webhooks/stripe/` |

Register these URLs in the Stripe Dashboard → Developers → Webhooks. The gateway validates the `Stripe-Signature` header using `STRIPE_WEBHOOK_SECRET` (synced through the current Secret Manager bridge from `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY`).

---

## Deployment

### First-Time Deploy

The manifests are included in the base kustomization and deploy with the rest of the platform:

```bash
# ArgoCD will auto-sync on merge to main.
# To manually apply (emergency only — see docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md):
kubectl apply -k deploy/k8s/base/
```

The `migrate` init container runs `alembic upgrade head` on every pod start — it is idempotent and safe to re-run.

### Startup sequence

Use this order when bringing up or revalidating the lane after a disruptive
change:

1. confirm `payments-gateway-secrets` is synced and recent
2. confirm PostgreSQL pod is ready and accepting connections
3. confirm the `migrate` init container completes successfully
4. confirm `payments-gateway` has endpoints and returns `200` from `/health/`
   and `/ready/`
5. confirm Caddy routing for `/payments/*`
6. confirm Stripe webhook secret and LMS OAuth client secret are present before
   declaring purchase readiness

If webhook or OAuth material is missing, the service may be up while the
purchase lane is still not operationally ready.

### Image Update

Use the governed build-and-promotion lane for any production image change. Do not manually build, push, and edit deployment YAML as the normal path.

Normal path:
1. publish the updated image through the governed build workflow
2. promote the resulting release coordinates through the sanctioned GitOps lane
3. let ArgoCD realize the updated deployment from git

If the purchase-gateway image tag itself must be changed in source, update both container references in:

```yaml
deploy/k8s/base/apps/purchase-gateway/deployment.yaml
```

Then verify the service package with:

```bash
./scripts/qa/verify-purchase-gateway-k8s.sh
```

### Verify After Deploy

```bash
# Offline manifest checks
./scripts/qa/verify-purchase-gateway-k8s.sh

# Live cluster checks
./scripts/qa/verify-purchase-gateway-k8s.sh --online
```

---

## Rollback

### Standard Rollback (one version back)

```bash
kubectl rollout undo deployment/payments-gateway -n mereka-lms
kubectl rollout status deployment/payments-gateway -n mereka-lms
```

Then revert the image tag in `deploy/k8s/base/apps/purchase-gateway/deployment.yaml` and push, so ArgoCD does not re-apply the bad version.

### Rollback to a Specific Revision

```bash
# List revision history
kubectl rollout history deployment/payments-gateway -n mereka-lms

# Roll back to revision 3
kubectl rollout undo deployment/payments-gateway -n mereka-lms --to-revision=3

# Commit the corresponding image tag to git immediately
```

**Important**: After any manual rollback, update the manifest in git within 5 minutes to prevent ArgoCD from re-applying the reverted version.

### Fulfillment rollback boundary

Roll back gateway API or worker images only after classifying which lane is
actually broken:

- webhook receipt broken -> fix gateway ingress, secret, or webhook path
- fulfillment broken after payment receipt -> use
  [PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md](PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md)
  to pause/replay jobs rather than immediately reverting everything
- LMS OAuth broken -> use
  [ECOMMERCE_OAUTH_TROUBLESHOOTING.md](ECOMMERCE_OAUTH_TROUBLESHOOTING.md)
  before treating the incident as a generic gateway outage

Do not call the lane healthy just because the API pod rolled back cleanly if
paid orders still cannot fulfill.

---

## Health Checks

### Quick Status

```bash
# Pod status
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway

# Service endpoints (empty = site unreachable)
kubectl get endpoints payments-gateway -n mereka-lms

# HPA status
kubectl get hpa payments-gateway -n mereka-lms

# ExternalSecret sync status
kubectl get externalsecret payments-gateway-secrets -n mereka-lms
```

### Health Endpoint via kubectl exec

```bash
POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

# Liveness
kubectl exec -n mereka-lms "$POD" -- \
  python3 -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/health/',timeout=5); print(r.status)"

# Readiness
kubectl exec -n mereka-lms "$POD" -- \
  python3 -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/ready/',timeout=5); print(r.status)"
```

Expected output: `200` for both.

### PostgreSQL Health

```bash
PG_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=postgresql-payments \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n mereka-lms "$PG_POD" -- \
  pg_isready -U payments -d payments_gateway
```

Expected: `payments_gateway - accepting connections`

### Purchase-readiness quick verdict

Treat the lane as purchase-ready only when all of the following are true:

- gateway pod healthy and ready
- Postgres reachable
- Caddy `/payments/*` route present
- Stripe webhook secret present and current
- LMS OAuth client secret present and accepted by current OAuth checks
- no unresolved dead-letter fulfillment backlog blocking current orders

Use these companions when the pod is healthy but the purchase lane is not:

- [STRIPE_WEBHOOKS_SETUP.md](STRIPE_WEBHOOKS_SETUP.md)
- [ECOMMERCE_OAUTH_TROUBLESHOOTING.md](ECOMMERCE_OAUTH_TROUBLESHOOTING.md)
- [PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md](PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md)

---

## Secret Rotation

### Rotate a Single Secret

1. Update the source secret in Infisical and sync the governed bridge:

```bash
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
```

2. Force `ExternalSecret` to re-sync immediately (optional — auto-syncs within 1h):

```bash
kubectl annotate externalsecret payments-gateway-secrets \
  -n mereka-lms \
  force-sync=$(date +%s) --overwrite
```

3. Verify the K8s secret was updated:

```bash
kubectl get secret payments-gateway-secrets -n mereka-lms \
  -o jsonpath='{.metadata.resourceVersion}'
# Run twice, 5s apart — resourceVersion should change
```

4. Restart the deployment to pick up the new secret:

```bash
kubectl rollout restart deployment/payments-gateway -n mereka-lms
kubectl rollout status deployment/payments-gateway -n mereka-lms
```

### Rotate Stripe Webhook Secret

The Stripe webhook secret (`MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY`) is tied to a specific Stripe webhook endpoint. When rotating:

1. Create a new webhook endpoint in the Stripe Dashboard.
2. Copy the new signing secret.
3. Sync the updated source secret through the governed bridge (step 1 above).
4. Wait for ExternalSecret sync or force it (step 2 above).
5. Restart the deployment (step 4 above).
6. Verify test webhook events reach the new endpoint.
7. Delete the old Stripe webhook endpoint.

Reference: `docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md`

### Rotate PostgreSQL Password

```bash
# 1. Generate a new password
NEW_PW=$(openssl rand -base64 32)

# 2. Sync the governed secrets bridge after updating the source secret
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# 3. Update the password in PostgreSQL (BEFORE the K8s secret updates)
PG_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=postgresql-payments \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mereka-lms "$PG_POD" -- \
  psql -U payments -d payments_gateway \
  -c "ALTER USER payments PASSWORD '$NEW_PW';"

# 4. Force ExternalSecret sync (picks up new DATABASE_URL and POSTGRESQL_PASSWORD)
kubectl annotate externalsecret payments-gateway-secrets \
  -n mereka-lms force-sync=$(date +%s) --overwrite

# 5. Restart payments-gateway (new DATABASE_URL injected)
kubectl rollout restart deployment/payments-gateway -n mereka-lms
```

---

## Live Traffic Status (ENABLE_GATEWAY_FULFILLMENT)

`ENABLE_GATEWAY_FULFILLMENT=true` is set in `deploy/k8s/base/apps/purchase-gateway/deployment.yaml`.

The gateway is activated. Before routing real user traffic, confirm:

- [ ] Real Stripe live-mode keys set in the governed secrets path (not test keys)
- [ ] Stripe webhook endpoint registered in the Stripe Dashboard:
  - Production: `https://academyv2.mereka.io/payments/webhooks/stripe/`
  - Dev: `https://academyv2.mereka.dev/payments/webhooks/stripe/`
- [ ] Stripe sends a test event and the gateway returns `{"status": "received"}`
- [ ] OAuth2 client `payments-gateway` registered in the LMS Django admin
- [ ] `LMS_OAUTH_CLIENT_SECRET` set correctly in the governed secrets path
- [ ] Legacy Oscar ecommerce service decommissioned (or routing rules updated)
- [ ] `./scripts/qa/verify-purchase-gateway-k8s.sh --online` returns 0 FAILs
- [ ] `./scripts/qa/verify-caddy-payments-route.sh` returns 0 FAILs
- [ ] Load test run against staging (100 concurrent checkouts target)

To disable fulfillment without removing the service (dark launch mode):

```yaml
# deploy/k8s/base/apps/purchase-gateway/deployment.yaml
- name: ENABLE_GATEWAY_FULFILLMENT
  value: "false"
```

Commit, push, and wait for ArgoCD sync.

---

## Troubleshooting

### Pod Not Starting

```bash
# Check events
kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=payments-gateway

# Check init container (Alembic migration) logs
kubectl logs -n mereka-lms deploy/payments-gateway -c migrate

# Check main container logs
kubectl logs -n mereka-lms deploy/payments-gateway --tail=100
```

Common causes:
- `migrate` init container fails: DATABASE_URL secret not synced yet, or PostgreSQL not ready
- `ImagePullBackOff`: image tag does not exist in GHCR / the active image registry, or RBAC issue
- `CrashLoopBackOff`: bad environment variable, DB connection refused, or startup error

### ExternalSecret Not Syncing

```bash
kubectl describe externalsecret payments-gateway-secrets -n mereka-lms
```

Check the `Status.Conditions` section for error messages. Common causes:
- GCP Workload Identity not configured for the ESO service account
- Secret is missing from the governed Secret Manager bridge after sync
- Secret name typo in `external-secrets.yaml`

### Service Has No Endpoints

```bash
kubectl get endpoints payments-gateway -n mereka-lms
# If output shows <none>, the pod selector is wrong

# Check pod labels match service selector
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway --show-labels
```

### Webhook events not arriving

If checkout completes in Stripe but orders stay `pending` or no webhook logs
arrive:

1. verify the registered Stripe endpoint URL matches the current gateway route
2. verify `STRIPE_WEBHOOK_SECRET` is present in `payments-gateway-secrets`
3. verify Caddy still strips the `/payments` prefix correctly
4. run the delivery probe from
   [STRIPE_WEBHOOKS_SETUP.md](STRIPE_WEBHOOKS_SETUP.md)
5. only after the gateway webhook lane is green, move to fulfillment replay

Webhook receipt failure is an ingress/secret problem, not a fulfillment replay
problem.

### Paid orders not fulfilling

If Stripe events are arriving but learners are not enrolled:

1. inspect gateway and worker logs for OAuth or LMS API failures
2. inspect failed or dead-letter jobs using
   [PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md](PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md)
3. verify LMS OAuth client and scopes using
   [ECOMMERCE_OAUTH_TROUBLESHOOTING.md](ECOMMERCE_OAUTH_TROUBLESHOOTING.md)
4. replay only after downstream auth/API health is confirmed

### Manual enrollment and refund boundary

Current manual operator actions are split deliberately:

- enrollment replay, failed jobs, and reconciliation belong in
  [PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md](PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md)
- Stripe webhook endpoint and secret setup belong in
  [STRIPE_WEBHOOKS_SETUP.md](STRIPE_WEBHOOKS_SETUP.md)
- LMS OAuth2 client and scope failures belong in
  [ECOMMERCE_OAUTH_TROUBLESHOOTING.md](ECOMMERCE_OAUTH_TROUBLESHOOTING.md)

Do not improvise direct DB edits or ad-hoc refunds from this runbook unless the
incident has already been classified and the governed recovery procedure calls
for them.

### PostgreSQL PVC Expansion

The PVC is 5Gi. If storage is filling up:

```bash
# Check current usage
kubectl exec -n mereka-lms -l app.kubernetes.io/name=postgresql-payments -- \
  df -h /var/lib/postgresql/data

# Expand (current storage class must support online expansion)
kubectl patch pvc postgresql-payments -n mereka-lms \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

### Database Migration Failures

If an Alembic migration fails on deploy:

```bash
# Check init container logs
kubectl logs -n mereka-lms deploy/payments-gateway -c migrate

# Connect to DB directly
PG_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=postgresql-payments \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n mereka-lms "$PG_POD" -- psql -U payments -d payments_gateway

# Check migration history
# (inside psql) SELECT * FROM alembic_version;
```

To run migration manually:

```bash
GW_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mereka-lms "$GW_POD" -- python -m alembic upgrade head
```

---

## Metrics and Observability

The gateway exposes Prometheus metrics at `/metrics/` (AC-029). Key metrics:

| Metric | Description |
|--------|-------------|
| `payments_checkout_total` | Total checkout sessions initiated |
| `payments_fulfillment_duration_seconds` | Fulfillment processing duration |
| `payments_webhook_processing_seconds` | Stripe webhook processing time |
| `payments_fulfillment_failed_total` | Failed fulfillments (alerts on > 0) |

Logs are structured JSON and ship via Promtail to Loki. Filter by service in Grafana:

```
{namespace="mereka-lms", app_kubernetes_io_name="payments-gateway"}
```

---

## Verification Scripts

```bash
# Caddy /payments/* route — prefix stripping, upstream, path mapping (CI-safe)
./scripts/qa/verify-caddy-payments-route.sh

# K8s manifest checks — deployment, service, ExternalSecrets, HPA, PostgreSQL (CI-safe)
./scripts/qa/verify-purchase-gateway-k8s.sh

# Full K8s verification including live cluster
./scripts/qa/verify-purchase-gateway-k8s.sh --online

# Comprehensive gateway checks — scaffold, Stripe, models, security, resilience
./scripts/qa/verify-purchase-gateway.sh
./scripts/qa/verify-purchase-gateway-stripe.sh
./scripts/qa/verify-purchase-gateway-security.sh
./scripts/qa/verify-purchase-gateway-resilience.sh
./scripts/qa/verify-purchase-gateway-models.sh
./scripts/qa/verify-purchase-gateway-metrics-contract.sh
```

All scripts exit 0 when all non-skipped checks pass. All are included in `.github/ci-scripts-static.txt` and run on every PR.
