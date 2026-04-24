# Oscar Ecommerce Deprecation Plan

## Status: Transition Period (dual-stack)

Oscar runs alongside Purchase Gateway with `ENABLE_GATEWAY_FULFILLMENT=false`. No new features or bug fixes are applied to Oscar. All new purchase-flow development targets Purchase Gateway.

**Decision record**: `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
**Spec**: `specs/ecommerce-purchase-gateway_spec.md`
**Audit script**: `scripts/qa/verify-oscar-deprecation.sh`

---

## Current State

### Services running in parallel

| Service | Namespace | Image | Status |
|---------|-----------|-------|--------|
| `ecommerce` Deployment | mereka-lms | overhangio/openedx-ecommerce:19.0.0 | Active, deprecated |
| `ecommerce-worker` Deployment | mereka-lms | overhangio/openedx-ecommerce-worker:19.0.0 | Active, deprecated |
| `payments-gateway` Deployment | mereka-lms | asia-southeast1-docker.pkg.dev/.../payments-gateway:0.1.1 | Active (dark launch) |

### Feature flag

`ENABLE_GATEWAY_FULFILLMENT` controls whether Purchase Gateway processes orders:

```yaml
# services/purchase-gateway/k8s/deployment.yaml
- name: ENABLE_GATEWAY_FULFILLMENT
  value: "false"   # ← dark launch: gateway deployed but not processing live orders yet
```

Setting this to `"true"` activates Purchase Gateway fulfillment. Oscar remains running in parallel until the decommission script (AC-028) removes it.

### What Oscar still owns

All live purchase flows until `ENABLE_GATEWAY_FULFILLMENT=true`:
- Course enrollment via Stripe (Oscar Stripe processor)
- Order history UI (`ecommerce.academyv2.mereka.io/dashboard/`)
- Basket and checkout flows (`/basket/`, `/checkout/`)
- OAuth2 service-to-service auth with LMS (`ecommerce` + `ecommerce-sso` clients)
- MySQL `ecommerce` database

### What Purchase Gateway already owns

- FastAPI application at `services/purchase-gateway/`
- PostgreSQL `payments` database (in-cluster, PVC provisioned)
- Redis job queue (DB 14)
- K8s Deployment + Service + HPA + ExternalSecrets
- Stripe webhook signature verification
- LMS enrollment via OAuth2/JWT service-to-service auth
- Dark-launched to production cluster (health: DB ok, Redis ok, Stripe key present)

---

## Migration Steps

Work through these phases in order. Do not remove Oscar resources until the phase that explicitly says to.

### Phase 1 — Complete Purchase Gateway implementation (AC-001 through AC-026)

Pre-requisites before any cutover:

- [ ] All AC-001..AC-026 automated tests passing (`scripts/qa/verify-purchase-gateway.sh`)
- [ ] Migration routing middleware implemented (`services/purchase-gateway/app/middleware/migration.py`)
  — new purchases go to gateway; in-flight Oscar orders complete on Oscar (AC-027)
- [ ] Caddy route added for Purchase Gateway external webhook access
  — `https://academyv2.mereka.{io,dev}/payments/*` → `payments-gateway:8080`
- [ ] Stripe live keys set in GCP Secret Manager (`bbi-k8` project):
  - `MEREKA_LMS_PAYMENTS_STRIPE_SECRET_KEY`
  - `MEREKA_LMS_PAYMENTS_STRIPE_WEBHOOK_SECRET`
- [ ] End-to-end purchase test on staging with real Stripe test keys

### Phase 2 — Enable fulfillment (cutover)

```bash
# 1. Confirm zero in-flight Oscar orders
kubectl exec -n mereka-lms deploy/ecommerce -- \
  python manage.py shell -c "from oscar.apps.order.models import Order; print(Order.objects.filter(status='Open').count())"

# 2. Enable Purchase Gateway fulfillment
kubectl set env deployment/payments-gateway -n mereka-lms ENABLE_GATEWAY_FULFILLMENT=true
# Also update services/purchase-gateway/k8s/deployment.yaml in git (GitOps)

# 3. Monitor for 24 hours:
# - Purchase Gateway: /metrics endpoint, Grafana dashboard
# - Oscar: watch for new orders (should be zero after cutover)
```

After cutover Oscar continues to handle its existing historical order data but receives no new orders.

### Phase 3 — Decommission Oscar (AC-028)

Run only after:
- Zero new Oscar orders for ≥ 7 days
- All historical orders in terminal state (`Complete` or `Cancelled`)
- Purchase Gateway handling 100% of purchase traffic

The decommission script to implement at `scripts/infra/decommission-legacy-ecommerce.sh` must:

1. **Verify pre-conditions**
   ```bash
   # Zero open orders in Oscar
   kubectl exec -n mereka-lms deploy/ecommerce -- \
     python manage.py shell -c "from oscar.apps.order.models import Order; assert Order.objects.filter(status='Open').count() == 0"
   ```

2. **Remove K8s resources** (commit to git, let ArgoCD apply — do NOT `kubectl delete` directly)
- `deploy/k8s/base/apps/` legacy ecommerce deployment and service manifests (legacy, removed from current repo)
- `deploy/k8s/base/plugins/` legacy Oscar plugin manifest subtree (legacy, removed from current repo)
- `deploy/k8s/base/kustomization.yaml`: remove `ecommerce-settings` and `ecommerce-worker-settings` ConfigMap references
- `deploy/k8s/base/plugins/` legacy Oscar plugin manifests (if present)
- `deploy/k8s/overlays/production/patches/resource-limits.yaml`: remove ecommerce/ecommerce-worker patches

3. **Remove Caddy routing**
   - `deploy/k8s/base/apps/caddy/Caddyfile`: remove both ecommerce server blocks (localhost and production)

4. **Remove ingress hosts**
   - `deploy/k8s/overlays/production/ingress-openedx-lms.yaml`: remove `ecommerce.academyv2.mereka.io`
   - `deploy/k8s/overlays/rke2-nonprod/ingress-openedx-lms.yaml`: remove ecommerce host (if present)
   - `deploy/k8s/overlays/local/ingress-openedx-lms.yaml`: remove ecommerce host (if present)

5. **Remove DNS records**
   - `infrastructure/cloudflare/records.json`: remove `ecommerce.academyv2.mereka.io`
   - `infrastructure/cloudflare/records.mereka-dev.json`: remove `ecommerce.academyv2.mereka.dev`
   - Apply via Cloudflare API or Terraform

6. **Remove LMS settings** (after Purchase Gateway is sole purchase path)
- `deploy/k8s/base/apps/openedx/settings/lms/*.py`: remove `ECOMMERCE_PUBLIC_URL_ROOT`, `ECOMMERCE_API_URL`

7. **Remove Oscar OAuth2 clients from LMS** (in-cluster)
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- \
     python manage.py lms shell -c "
   from oauth2_provider.models import Application
   for cid in ('ecommerce', 'ecommerce-sso'):
       app = Application.objects.filter(client_id=cid).first()
       if app:
           app.delete()
           print(f'Deleted OAuth2 client: {cid}')
   "
   ```

8. **Remove secrets** (after Deployment removed)
   - Remove from `deploy/k8s/base/secrets/external-secrets.yaml`:
     `JWT_SECRET_KEY_ECOMMERCE`, `ECOMMERCE_API_SIGNING_KEY`, `ECOMMERCE_EDX_API_KEY`,
     `ECOMMERCE_SECRET_KEY`, `ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET`,
     `ECOMMERCE_BACKEND_OAUTH2_SECRET`, `MYSQL_ECOMMERCE_PASSWORD`
   - Remove from `deploy/k8s/base/secrets/openedx-secrets.yaml`: same keys
   - Archive (do not delete immediately) in Infisical and GCP Secret Manager

9. **Remove monitoring**
   - Delete `infrastructure/monitoring/uptime/prod-ecommerce-https.json`
   - Remove ecommerce host from `infrastructure/monitoring/alerts/https-cert-expiry.json`
   - Remove ecommerce from `infrastructure/monitoring/dashboards/public-endpoints.json`
   - Remove ecommerce from `infrastructure/k8s/cronjobs/cert-verify-prod.yaml`
   - Remove ecommerce from `infrastructure/k8s/cronjobs/auth-verify-prod.yaml`

10. **Archive Oscar settings**
    - Retain legacy Oscar references in `docs/archive/` (for incident post-mortem and rollback notes)
    - Replace archived references with current canonical manifests and runbooks once they are reintroduced into a cleanup PR

11. **Update documentation**
    - `docs/meta/standing-orders/README.md` or other canonical standing orders: remove ecommerce from active operator summaries if still present
    - `infrastructure/tutor/README.md`: remove ecommerce from plugin list
    - `docs/reference/operations/AUTH_AND_PERMISSIONS.md`: remove ecommerce service references
    - `docs/ops/quickref/kubectl-cheatsheet.md`: remove ecommerce entries
    - Update `specs/k8s-deployment_spec.md` to remove ecommerce rows from service table
    - Update `specs/secrets-management_spec.md` to remove ecommerce secret rows

---

## Rollback Plan

### During Phase 2 (after cutover, before decommission)

Oscar is still running. To roll back:

```bash
# 1. Disable Purchase Gateway fulfillment
kubectl set env deployment/payments-gateway -n mereka-lms ENABLE_GATEWAY_FULFILLMENT=false
# Update git simultaneously

# 2. Verify Oscar is still healthy
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=ecommerce
kubectl logs -n mereka-lms deploy/ecommerce --tail=50

# 3. Direct Stripe webhook back to Oscar (via Stripe dashboard)
# Oscar webhook: https://ecommerce.academyv2.mereka.io/payment/stripe/webhooks/

# 4. Reconcile any orders that landed in Purchase Gateway
# - Purchase Gateway orders in state 'pending': manual fulfillment via admin API
# - No refunds needed if no fulfillment happened (ENABLE_GATEWAY_FULFILLMENT=false)
```

Oscar handles all new orders immediately. Purchase Gateway orders can be fulfilled manually if any slipped through.

### During Phase 3 (after decommission starts)

If decommission reveals a blocking issue:

1. Revert the git commit(s) that removed the K8s resources — ArgoCD will restore Oscar
2. Re-create DNS records if already removed
3. Re-configure Stripe webhook endpoint in the Stripe dashboard to point back to Oscar

**Oscar's MySQL database is NOT dropped during decommission.** Retain the `ecommerce` database in Cloud SQL for at least 6 months after decommission for audit/rollback purposes. Add a Cloud SQL scheduled snapshot before decommission begins.

---

## Decommission Criteria (from spec AC-028)

All of the following must be true before running the decommission script:

- [ ] Zero Oscar orders in state `Open` or `Payment Pending`
- [ ] `ENABLE_GATEWAY_FULFILLMENT=true` for ≥ 7 consecutive days with no incidents
- [ ] Purchase Gateway processing 100% of new purchases (verify via Grafana)
- [ ] No open P1/P2 incidents involving Purchase Gateway
- [ ] `scripts/qa/verify-purchase-gateway.sh` returns PASS for all AC-001..AC-026
- [ ] Engineering lead sign-off on decommission PR

---

## File Inventory

Run `scripts/qa/verify-oscar-deprecation.sh` at any time for a live categorised view of all Oscar references. The categories are:

| Category | Meaning |
|----------|---------|
| `KEEP` | Active Oscar resource needed while dual-stack is running. Do not remove. |
| `REMOVE` | Oscar artifact that can be removed after Purchase Gateway cutover. Schedule for Phase 3. |
| `MIGRATE` | Missing Purchase Gateway equivalent that must exist before Oscar can be removed. Implement in Phase 1. |

---

## Timeline (target)

| Phase | Trigger | Target |
|-------|---------|--------|
| Phase 1 complete | AC-001..AC-026 all pass | Before next release cycle |
| Phase 2 cutover | Phase 1 complete + Stripe live keys set | Coordinated with product sign-off |
| Phase 3 decommission | 7 days post-cutover with zero incidents | ≥ 1 week after Phase 2 |
| Oscar DB archived | 6 months post-decommission | Scheduled Cloud SQL snapshot |
