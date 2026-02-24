# Release Packet — Production State 2026-02-18

> **Bead**: mereka-lms-i5yy.1
> **AC**: AC-OPS-004
> **Date**: 2026-02-18
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## Current Deployed Images (Production)

| Component | Image | Tag |
|-----------|-------|-----|
| LMS / CMS / Workers | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx` | `mereka-brand` |
| MFE | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe` | `20260208-mfe-discussions-pass4-c17df16` |
| Payments Gateway | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/payments-gateway` | `0.1.1` |

Source: `deploy/k8s/overlays/production/kustomization.yaml`

---

## Live Deployment Status (2026-02-18)

| Deployment | Ready | Replicas |
|------------|-------|---------|
| lms | 2/2 | 2 |
| cms | 1/1 | 1 |
| lms-worker | 1/1 | 1 |
| cms-worker | 1/1 | 1 |
| caddy | 1/1 | 1 |
| mfe | 1/1 | 1 |
| discovery | 1/1 | 1 |
| notes | 1/1 | 1 |
| credentials | 1/1 | 1 |
| ecommerce | 1/1 | 1 |
| ecommerce-worker | 1/1 | 1 |
| elasticsearch | 1/1 | 1 |
| enterprise-access | 1/1 | 1 |
| enterprise-access-worker | 1/1 | 1 |
| enterprise-admin-portal | 1/1 | 1 |
| enterprise-catalog | 1/1 | 1 |
| enterprise-catalog-worker | 1/1 | 1 |
| enterprise-learner-portal | 1/1 | 1 |
| enterprise-subsidy | 1/1 | 1 |
| license-manager | 1/1 | 1 |
| meilisearch | 1/1 | 1 |
| mysql | 1/1 | 1 |
| redis | 1/1 | 1 |
| payments-gateway | 1/1 | 1 |
| postgresql-payments | 1/1 | 1 |
| smtp | 1/1 | 1 |
| xqueue | 1/1 | 1 |
| mux-delivery-monitor | 0/1 | 1 (CreateContainerConfigError — MUX_TOKEN_ID missing, non-blocking) |

**Overall**: 26/27 deployments fully ready. 1 non-blocking degraded (mux-delivery-monitor).

---

## Rollout Commands (Next Release)

```bash
# 1. Build and push new openedx image
tutor images build openedx
docker tag openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<new-tag>
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<new-tag>

# 2. Update kustomization.yaml with new tag
# Edit deploy/k8s/overlays/production/kustomization.yaml:
#   newTag: <new-tag>

# 3. Commit and push (ArgoCD auto-syncs)
git add deploy/k8s/overlays/production/kustomization.yaml
git commit -m "chore(deploy): update openedx image to <new-tag>"
git push origin main

# 4. Monitor rollout
kubectl rollout status deployment/lms -n mereka-lms
kubectl rollout status deployment/cms -n mereka-lms
kubectl rollout status deployment/lms-worker -n mereka-lms
```

---

## Rollback Commands

```bash
# Revert kustomization.yaml to previous tag
git revert HEAD
git push origin main

# Or manual rollback
kubectl rollout undo deployment/lms -n mereka-lms
kubectl rollout undo deployment/cms -n mereka-lms
```

---

## Known Issues / Deferreds

| Issue | Impact | Action |
|-------|--------|--------|
| `mux-delivery-monitor` CreateContainerConfigError | Video delivery monitoring only | Add `MUX_TOKEN_ID` to `mereka-lms-runtime-secrets` when Mux contract active |
| `auth-verify-prod` CronJob errors (45h old) | Monitoring noise | Recent job completed (7m ago) — transient, monitoring |
| Purchase Gateway dark launch | Ecommerce path inactive | Activate with real Stripe keys + `ENABLE_GATEWAY_FULFILLMENT=true` |
| Legacy ecommerce (`ecommerce.academyv2.mereka.io`) | Oscar still serving | Decommission after purchase-gateway is activated |

---

## Next Deployment Gates

Before activating purchase-gateway in production:
1. Add real Stripe keys to GCP SM (`MEREKA_LMS_STRIPE_SECRET_KEY`, `MEREKA_LMS_STRIPE_PUBLISHABLE_KEY`)
2. Add Caddy route for payment webhook external access
3. Set `ENABLE_GATEWAY_FULFILLMENT=true` in payments-gateway deployment env
4. Run smoke test on `/health` and Stripe webhook endpoint
