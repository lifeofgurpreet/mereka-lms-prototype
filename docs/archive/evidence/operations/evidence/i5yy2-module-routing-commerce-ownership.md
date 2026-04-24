# Module Routing and E-Commerce Ownership — Deployment Blockers

> **Bead**: mereka-lms-i5yy.2
> **ACs**: AC-OPS-101, AC-OPS-102, AC-OPS-103
> **Date**: 2026-02-18

---

## AC-OPS-101: Active E-Commerce Path and Custom Backend Ownership

### Current E-Commerce Architecture

| Component | Status | Owner | Notes |
|-----------|--------|-------|-------|
| Legacy Oscar Ecommerce | Running (dark, deprecated) | Platform team | `docker.io/overhangio/openedx-ecommerce:19.0.0` at `ecommerce.academyv2.mereka.io` |
| Purchase Gateway | Running (dark launch) | Platform team | `payments-gateway:0.1.1` at internal port 8000 |
| Purchase Gateway DB | Running | Platform team | `postgresql-payments` in-cluster |
| Stripe integration | Not active | Platform team | Keys not yet in GCP SM; `ENABLE_GATEWAY_FULFILLMENT=false` |

**Active purchase path**: Legacy Oscar (deprecated but serving). Purchase Gateway is dark — no orders routed to it yet.

**Authoritative ADR**: `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` (Status: ACCEPTED)

**Spec**: `specs/ecommerce-purchase-gateway_spec.md` (33 ACs, all automated)

### Backend Ownership

| Backend | Code Location | Owner |
|---------|--------------|-------|
| Purchase Gateway (FastAPI) | `services/purchase-gateway/` | Platform/backend |
| Legacy Oscar (upstream) | `docker.io/overhangio/openedx-ecommerce` | Upstream (no custom fork) |

---

## AC-OPS-102: Module Routing — Legacy E-Commerce Reference Cleanup

### References Removed / Deprecated

| Location | Legacy Reference | Status |
|----------|-----------------|--------|
| `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` | `ecommerce.academyv2.mereka.io` | ACTIVE — retained during transition (ADR-018 decommission criteria not yet met) |
| `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` | Legacy service docs | Explicitly deprecated, decommission criteria documented |

**Decommission criteria (from ADR-018)**:
- [ ] Zero pods, zero DNS records, zero OAuth2 clients for legacy ecommerce
- [ ] All purchase flows verified on purchase-gateway
- [ ] Enterprise onboarding validated

Current status: criteria not met. Legacy service remains active intentionally.

**Action required before decommission**:
1. Add real Stripe keys to GCP SM
2. Set `ENABLE_GATEWAY_FULFILLMENT=true`
3. Run purchase-gateway smoke test suite
4. Remove legacy ecommerce ingress and K8s deployment
5. Remove OAuth2 client for legacy service

---

## AC-OPS-103: Remaining Deployment Blockers

### Analytics

| Item | Status |
|------|--------|
| Segment analytics key injection | RESOLVED — sentinel filtering hardened (2dcy.5) |
| Aspects/ClickHouse analytics | NOT DEPLOYED — Tutor-aspects plugin not integrated; deferred to separate lane |
| xAPI event bus | ACTIVE — Redis Streams, event routing functional |

### Commerce Module Blockers

| Blocker | Status | Unblock Path |
|---------|--------|--------------|
| Stripe secret keys in GCP SM | MISSING | Operator action: `gcloud secrets versions add MEREKA_LMS_STRIPE_SECRET_KEY` |
| `ENABLE_GATEWAY_FULFILLMENT=false` | INTENTIONAL | Flip to `true` after Stripe key setup + smoke test |
| Legacy ecommerce decommission | DEFERRED | ADR-018 decommission criteria — requires purchase-gateway activation first |

### Tenant Module Integration

| Module | Status |
|--------|--------|
| Multi-tenancy Django plugin | ACTIVE — `infrastructure/tutor/plugins/multi-tenancy/` |
| Enterprise services | ACTIVE — all 5 enterprise service deployments running |
| Per-tenant branding | ACTIVE — SiteConfiguration overlays functional |
| Per-tenant course catalog | ACTIVE — `course_org_filter` enforced per `multisite-sites.yml` |

---

## Deployment Blocker Summary

| Blocker | Priority | Owner | ETA |
|---------|----------|-------|-----|
| Stripe keys in GCP SM | P1 | Platform ops | On operator action |
| Aspects/ClickHouse analytics | P3 | Analytics team | Separate roadmap item |
| Legacy ecommerce decommission | P2 | Platform team | After purchase-gateway activation |

**No P0 blockers**. Platform is deployable and serving all active tenants.

---

## References

- `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- `docs/architecture/purchase-gateway-overview.md`
- `docs/ops/runbooks/purchase-gateway-runbook.md`
- `services/purchase-gateway/` — FastAPI service source
- `deploy/k8s/base/apps/payments-gateway/` — K8s manifests
