# Legacy Oscar Ecommerce Removal Checklist
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

**Status**: NOT YET EXECUTED — Planning document only

**Background**: The legacy Oscar-based ecommerce service is being replaced by the custom Purchase Gateway (`services/purchase-gateway/`). See `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` for the decision rationale.

**Completion Criteria**: All items checked, runtime verified, then execute.

---

## Pre-Removal Verification

- [ ] Confirm Purchase Gateway is handling 100% of purchase flows (no legacy routing)
- [ ] Verify zero in-flight orders in legacy ecommerce database (pending/fulfilling status)
- [ ] Run `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=ecommerce` to identify legacy pods
- [ ] Export historical order data from legacy ecommerce MySQL to Purchase Gateway PostgreSQL

---

## DNS and Routing

- [ ] Remove `ecommerce.academyv2.mereka.io` from Caddy reverse proxy configuration
- [ ] Remove `ecommerce.academyv2.mereka.dev` from Caddy reverse proxy configuration
- [ ] Remove DNS A/CNAME records for ecommerce subdomains from Cloudflare
- [ ] Verify no ingress routes pointing to legacy ecommerce service

---

## Kubernetes Resources

- [ ] Delete ecommerce Deployment: `kubectl delete deployment ecommerce -n mereka-lms`
- [ ] Delete ecommerce-worker Deployment: `kubectl delete deployment ecommerce-worker -n mereka-lms`
- [ ] Delete ecommerce Service: `kubectl delete service ecommerce -n mereka-lms`
- [ ] Delete ecommerce ConfigMaps (if any)
- [ ] Remove legacy ecommerce references from `deploy/k8s/base/apps/purchase-gateway/`
- [ ] Remove ecommerce references from Kustomize overlays

---

## Secrets and Configuration

- [ ] Disable ecommerce OAuth2 clients in LMS Django admin:
  - Navigate to `/admin/oauth2_provider/application/`
  - Find client ID `ecommerce` and set `active=False`
- [ ] Archive ecommerce secrets in Infisical (mark as deprecated, retain for 90 days):
  - `MEREKA_LMS_ECOMMERCE_SECRET_KEY`
  - `MEREKA_LMS_ECOMMERCE_DB_PASSWORD`
  - `MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET`
- [ ] Remove ecommerce ExternalSecret mappings from `deploy/k8s/base/secrets/external-secrets.yaml`
- [ ] Remove ecommerce database from Cloud SQL (or archive if historical data needed)

---

## Documentation Updates

- [ ] Archive legacy ecommerce docs to `docs/archive/superseded/operations/`:
  - `docs/reference/operations/ECOMMERCE_THEMING.md`
  - `docs/ops/runbooks/ECOMMERCE_OAUTH_TROUBLESHOOTING.md`
  - `docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md` (if Oscar-specific sections)
- [ ] Remove ecommerce references from `docs/ops/quickref/access-urls.md`
- [ ] Remove ecommerce references from `docs/reference/operations/USER_FACING_URLS.md`
- [ ] Update `docs/reference/operations/CAPABILITY_MATRIX.md` to remove legacy ecommerce row
- [ ] Remove ecommerce from `docs/reference/operations/RUNTIME_TRUTH_MATRIX.md` declared host matrix
- [ ] Update `scripts/shared/config.sh` to remove `ECOMMERCE_DOMAIN` and `DEV_ECOMMERCE_DOMAIN` variables

---

## Verification After Removal

- [ ] Run smoke tests: `./scripts/qa/public-health-check.sh prod`
- [ ] Verify purchase flows work end-to-end via Purchase Gateway
- [ ] Verify ecommerce URLs return 404 or redirect to purchase-gateway
- [ ] Check Grafana for zero traffic to legacy ecommerce endpoints
- [ ] Run `kubectl get all -n mereka-lms | grep ecommerce` returns no results
- [ ] Verify no broken links in documentation (search for `ecommerce.academyv2.mereka`)

---

## Rollback Plan (If Needed)

- [ ] Keep legacy ecommerce Docker images in Artifact Registry for 90 days
- [ ] Retain ecommerce Kubernetes manifests in Git history (do not force-push)
- [ ] Document rollback procedure:
  1. Scale ecommerce Deployment to 1 replica
  2. Restore DNS records
  3. Re-enable OAuth2 client
  4. Update Caddy routing
  5. Toggle frontend feature flag back to legacy

---

**Estimated Execution Time**: 4-6 hours (includes verification)

**Owner**: Platform Engineering

**Review Before Execution**: Verify Purchase Gateway has been handling 100% of production traffic for at least 2 weeks with zero critical incidents.
