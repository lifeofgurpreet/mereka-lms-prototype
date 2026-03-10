# Purchase Gateway K8s Operations

<!-- Last verified: 2026-02-24 -->

_Audience: Developers & SRE | Owner: SRE | Status: Active_

Operations guide for the Purchase Gateway service deployed in the `mereka-lms` GKE namespace. The Purchase Gateway is the canonical replacement for the deprecated Oscar/ecommerce service.

Related: `specs/ecommerce-purchase-gateway_spec.md` | `docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md`

---

## Architecture

### Components

| Component | K8s Resource | Port | Image |
|-----------|--------------|------|-------|
| payments-gateway | Deployment | 8080 | `ghcr.io/biji-biji-initiative/mereka-lms/payments-gateway:0.1.1` |
| postgresql-payments | Deployment | 5432 | `docker.io/postgres:16-alpine` |
| postgresql-payments | PVC | — | 5Gi, ReadWriteOnce |
| payments-gateway | HPA | — | minReplicas=1, maxReplicas=3, CPU=70% |
| payments-gateway-secrets | ExternalSecret | — | synced from GCP SM every 1h |

### Manifests Location

```
services/purchase-gateway/k8s/
  deployment.yaml           # FastAPI app + Alembic init container
  service.yaml              # ClusterIP:8080
  hpa.yaml                  # autoscaling/v2
  external-secrets.yaml     # 6 GCP Secret Manager refs
  postgresql-deployment.yaml
  postgresql-service.yaml   # ClusterIP:5432
  postgresql-pvc.yaml       # 5Gi data volume
  kustomization.yaml
```

Referenced by `deploy/k8s/base/kustomization.yaml` as `../../../services/purchase-gateway/k8s`.

### Secrets (GCP Secret Manager — project: bbi-k8)

| K8s Key | GCP Secret Name |
|---------|-----------------|
| `SECRET_KEY` | `MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY` |
| `DATABASE_URL` | `MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL` |
| `STRIPE_SECRET_KEY` | `MEREKA_LMS_STRIPE_SECRET_KEY` |
| `STRIPE_WEBHOOK_SECRET` | `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY` |
| `LMS_OAUTH_CLIENT_SECRET` | `MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET` |
| `POSTGRESQL_PASSWORD` | `MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD` |

All secrets sync via `ExternalSecret` -> `ClusterSecretStore: gcp-secret-manager` (project `bbi-k8`, not `mereka-lms`).

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

Register these URLs in the Stripe Dashboard → Developers → Webhooks. The gateway validates the `Stripe-Signature` header using `STRIPE_WEBHOOK_SECRET` (synced from GCP SM `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY`).

---

## Deployment

### First-Time Deploy

The manifests are included in the base kustomization and deploy with the rest of the platform:

```bash
# ArgoCD will auto-sync on merge to main.
# To manually apply (emergency only — see gitops-enforcement rules):
kubectl apply -k deploy/k8s/base/
```

The `migrate` init container runs `alembic upgrade head` on every pod start — it is idempotent and safe to re-run.

### Image Update

1. Build and push the new image:

```bash
docker build -t ghcr.io/biji-biji-initiative/mereka-lms/payments-gateway:NEW_TAG \
  services/purchase-gateway/
docker push ghcr.io/biji-biji-initiative/mereka-lms/payments-gateway:NEW_TAG
```

2. Update the image tag in `services/purchase-gateway/k8s/deployment.yaml`:

```yaml
image: ghcr.io/biji-biji-initiative/mereka-lms/payments-gateway:NEW_TAG
```

3. Also update the init container image tag (same file, `migrate` container).

4. Commit and push — ArgoCD will roll out the new deployment.

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

Then revert the image tag in `services/purchase-gateway/k8s/deployment.yaml` and push, so ArgoCD does not re-apply the bad version.

### Rollback to a Specific Revision

```bash
# List revision history
kubectl rollout history deployment/payments-gateway -n mereka-lms

# Roll back to revision 3
kubectl rollout undo deployment/payments-gateway -n mereka-lms --to-revision=3

# Commit the corresponding image tag to git immediately
```

**Important**: After any manual rollback, update the manifest in git within 5 minutes to prevent ArgoCD from re-applying the reverted version.

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

---

## Secret Rotation

### Rotate a Single Secret

1. Update the secret value in GCP Secret Manager (project `bbi-k8`):

```bash
printf '%s' 'NEW_VALUE' | \
  gcloud secrets versions add MEREKA_LMS_STRIPE_SECRET_KEY \
    --data-file=- --project=bbi-k8
```

2. Force ExternalSecret to re-sync immediately (optional — auto-syncs within 1h):

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
3. Add a new GCP Secret Manager version (step 1 above).
4. Wait for ExternalSecret sync or force it (step 2 above).
5. Restart the deployment (step 4 above).
6. Verify test webhook events reach the new endpoint.
7. Delete the old Stripe webhook endpoint.

Reference: `docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md`

### Rotate PostgreSQL Password

```bash
# 1. Generate a new password
NEW_PW=$(openssl rand -base64 32)

# 2. Update GCP Secret Manager
printf '%s' "$NEW_PW" | \
  gcloud secrets versions add MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD \
    --data-file=- --project=bbi-k8

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

`ENABLE_GATEWAY_FULFILLMENT=true` is set in `services/purchase-gateway/k8s/deployment.yaml`.

The gateway is activated. Before routing real user traffic, confirm:

- [ ] Real Stripe live-mode keys set in GCP SM (not test keys)
- [ ] Stripe webhook endpoint registered in the Stripe Dashboard:
  - Production: `https://academyv2.mereka.io/payments/webhooks/stripe/`
  - Dev: `https://academyv2.mereka.dev/payments/webhooks/stripe/`
- [ ] Stripe sends a test event and the gateway returns `{"status": "received"}`
- [ ] OAuth2 client `payments-gateway` registered in the LMS Django admin
- [ ] `LMS_OAUTH_CLIENT_SECRET` set correctly in GCP SM
- [ ] Legacy Oscar ecommerce service decommissioned (or routing rules updated)
- [ ] `./scripts/qa/verify-purchase-gateway-k8s.sh --online` returns 0 FAILs
- [ ] `./scripts/qa/verify-caddy-payments-route.sh` returns 0 FAILs
- [ ] Load test run against staging (100 concurrent checkouts target)

To disable fulfillment without removing the service (dark launch mode):

```yaml
# services/purchase-gateway/k8s/deployment.yaml
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
- `ImagePullBackOff`: image tag does not exist in Artifact Registry or RBAC issue
- `CrashLoopBackOff`: bad environment variable, DB connection refused, or startup error

### ExternalSecret Not Syncing

```bash
kubectl describe externalsecret payments-gateway-secrets -n mereka-lms
```

Check the `Status.Conditions` section for error messages. Common causes:
- GCP Workload Identity not configured for the ESO service account
- Secret does not exist in GCP SM project `bbi-k8` (not `mereka-lms`)
- Secret name typo in `external-secrets.yaml`

### Service Has No Endpoints

```bash
kubectl get endpoints payments-gateway -n mereka-lms
# If output shows <none>, the pod selector is wrong

# Check pod labels match service selector
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=payments-gateway --show-labels
```

### PostgreSQL PVC Expansion

The PVC is 5Gi. If storage is filling up:

```bash
# Check current usage
kubectl exec -n mereka-lms -l app.kubernetes.io/name=postgresql-payments -- \
  df -h /var/lib/postgresql/data

# Expand (GKE standard storage class supports online expansion)
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
