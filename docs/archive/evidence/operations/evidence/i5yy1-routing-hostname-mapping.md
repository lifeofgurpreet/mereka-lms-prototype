# Routing and Hostname Mapping — Enterprise Domains and Tenant Aliases

> **Bead**: mereka-lms-i5yy.1
> **AC**: AC-OPS-001
> **Date**: 2026-02-18
> **Source**: `deploy/k8s/overlays/production/`, `infrastructure/tutor/multisite-sites.yml`

---

## Production Domains (Canonical)

### Mereka Academy (Primary Tenant)

| Service | Hostname | Backend | TLS |
|---------|----------|---------|-----|
| LMS | `academyv2.mereka.io` | caddy → lms | letsencrypt-prod |
| LMS Preview | `preview.academyv2.mereka.io` | caddy → lms | letsencrypt-prod |
| Studio/CMS | `studio.academyv2.mereka.io` | caddy → cms | letsencrypt-prod |
| MFE | `apps.academyv2.mereka.io` | caddy → mfe | letsencrypt-prod |
| Discovery | `discovery.academyv2.mereka.io` | caddy → discovery | letsencrypt-prod |
| Notes | `notes.academyv2.mereka.io` | caddy → notes | letsencrypt-prod |
| Credentials | `credentials.academyv2.mereka.io` | caddy → credentials | letsencrypt-prod |
| Ecommerce (legacy) | `ecommerce.academyv2.mereka.io` | caddy → ecommerce | letsencrypt-prod |
| Enterprise Admin | `admin.academyv2.mereka.io` | caddy (enterprise-mfe ingress) | letsencrypt-prod |
| Enterprise Portal | `enterprise.academyv2.mereka.io` | caddy (enterprise-mfe ingress) | letsencrypt-prod |

### Biji-Biji Academy (Tenant Alias)

| Service | Hostname | Maps To | TLS |
|---------|----------|---------|-----|
| LMS | `academy.biji-biji.com` | caddy → lms (SiteConfiguration: BIJIBIJI) | letsencrypt-prod |
| Studio/CMS | `studio.academy.biji-biji.com` | caddy → cms | letsencrypt-prod |
| MFE | `apps.academy.biji-biji.com` | caddy → mfe | letsencrypt-prod |

### Skill Our Future (Tenant Alias)

| Service | Hostname | Maps To | TLS |
|---------|----------|---------|-----|
| LMS | `skillourfuture.academy.mereka.io` | caddy → lms (SiteConfiguration: SKILLOURFUTURE) | letsencrypt-prod |
| Studio/CMS | `studio.academyv2.mereka.io` (shared) | caddy → cms | letsencrypt-prod |
| MFE | `apps.academyv2.mereka.io` (shared) | caddy → mfe | letsencrypt-prod |

---

## Routing Architecture

```
Browser → NGINX Ingress (GKE) → Caddy (port 80) → Service pods
```

All external HTTPS terminated at NGINX Ingress. Caddy handles internal HTTP routing and virtual-host dispatch.

**Ingress class**: `nginx`
**Cert issuer**: `cert-manager.io/cluster-issuer: letsencrypt-prod`
**Namespace**: `mereka-lms`

---

## Tenant Alias Resolution

Tenant aliases are resolved via Django `SiteConfiguration`:

| Domain | Org Code | Course Filter | Theme |
|--------|----------|---------------|-------|
| `academyv2.mereka.io` | MEREKA | `[MEREKA]` | mereka |
| `academy.biji-biji.com` | BIJIBIJI | `[BIJIBIJI]` | mereka |
| `skillourfuture.academy.mereka.io` | SKILLOURFUTURE | `[SKILLOURFUTURE]` | mereka |

Source: `infrastructure/tutor/multisite-sites.yml`

---

## Enterprise Services (Internal)

| Service | Internal Port | Notes |
|---------|--------------|-------|
| enterprise-catalog | 8160 | B2B course catalog API |
| enterprise-subsidy | 18280 | License/subscription management |
| enterprise-access | 18270 | Enrollment policy enforcement |
| license-manager | internal | License allocation |
| enterprise-learner-portal | internal | Learner-facing enterprise portal (MFE) |
| enterprise-admin-portal | internal | Admin portal MFE |

External access: `admin.academyv2.mereka.io` and `enterprise.academyv2.mereka.io` via enterprise-mfe ingress.

---

## Purchase Gateway (Dark Launch)

| Item | Value |
|------|-------|
| Service | `payments-gateway` |
| Internal port | 8000 |
| Status | Running, `ENABLE_GATEWAY_FULFILLMENT=false` |
| External access | Not yet exposed (dark launch) |
| DB | `postgresql-payments` (in-cluster, port 5432) |

**To activate**: Add Caddy route, set `ENABLE_GATEWAY_FULFILLMENT=true`, configure real Stripe keys in GCP SM.

---

## Deferred / Inactive Domains

| Hostname | Status | Notes |
|----------|--------|-------|
| `ecommerce.academyv2.mereka.io` | Active (legacy Oscar) | Being replaced by purchase-gateway |
| Mux video delivery | Inactive | `MUX_TOKEN_ID` missing from secrets; `mux-delivery-monitor` in CreateContainerConfigError |

---

## Source Files

- `deploy/k8s/overlays/production/ingress-openedx-lms.yaml`
- `deploy/k8s/overlays/production/ingress-openedx-mfe.yaml`
- `deploy/k8s/overlays/production/ingress-openedx-studio.yaml`
- `deploy/k8s/overlays/production/ingress-enterprise-mfe.yaml`
- `infrastructure/tutor/multisite-sites.yml`
