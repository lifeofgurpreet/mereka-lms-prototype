# Legacy Ecommerce Deprecation Inventory

_Audience: Platform Engineering + Operations • Last updated: 2026-02-17_

## Purpose

Inventory of all learner-facing and admin-facing paths/configs that reference the legacy Oscar/Django ecommerce service, with disposition actions.

**Decision**: ADR-018 — Purchase Gateway replaces Oscar Ecommerce.

## Inventory

### Learner-Facing Paths

| Path/URL | Location | Current Status | Action | Priority |
|----------|----------|---------------|--------|----------|
| `/orders*` | MFE routes | Not configured | ADD proxy to payments-gateway:8080 when ready | Future |
| `/payment*` | MFE routes | Not configured | ADD proxy to payments-gateway:8080 when ready | Future |
| `ecommerce.academyv2.mereka.io` | Caddyfile lines 151-168 | Active (splash page with links) | REDIRECT to /courses when gateway live | Medium |
| `/basket/` | Caddyfile line 162 (splash HTML) | Active link in splash page | REMOVE link from splash | High |
| `/checkout/` | Caddyfile line 162 (splash HTML) | Active link in splash page | REMOVE link from splash | High |

### LMS Configuration

| Setting | File | Current Value | Action | Priority |
|---------|------|--------------|--------|----------|
| `ECOMMERCE_PUBLIC_URL_ROOT` | lms/production.py line 788 | `MEREKA_ECOMMERCE_BASE_URL` | UPDATE to purchase-gateway URL | Medium |
| `ECOMMERCE_API_URL` | lms/production.py line 789 | `ECOMMERCE_PUBLIC_URL_ROOT + "/api/v2"` | UPDATE to purchase-gateway API | Medium |
| `ORDER_HISTORY_MICROFRONTEND_URL` | lms/production.py line 790 | `{MEREKA_MFE_BASE_URL}/orders/orders` | UPDATE when new orders UI ready | Low |
| `MFE_CONFIG["ECOMMERCE_BASE_URL"]` | lms/production.py line 791 | `ECOMMERCE_PUBLIC_URL_ROOT` | UPDATE to purchase-gateway | Medium |
| `MFE_CONFIG_API_URLS["orders"]` | lms/production.py line 808 | `{MEREKA_MFE_BASE_URL}/orders` | Routes defined but not proxied yet | Future |
| `MFE_CONFIG_API_URLS["payment"]` | lms/production.py line 809 | `{MEREKA_MFE_BASE_URL}/payment` | Routes defined but not proxied yet | Future |

### Tutor/Infrastructure

| Config | File | Status | Action |
|--------|------|--------|--------|
| Ecommerce plugin | config.example.yml | Marked DEPRECATED | KEEP (transition period) |
| Ecommerce K8s configs | deploy/k8s/base/plugins/ecommerce/ | Active | KEEP until AC-027/AC-028 close |

## Disposition Summary

| Action | Count | Timing |
|--------|-------|--------|
| REMOVE (UI cleanup) | 2 | Now (non-destructive) |
| UPDATE (point to gateway) | 4 | When purchase-gateway is production-ready |
| ADD (new proxy routes) | 2 | When purchase-gateway is production-ready |
| KEEP (transition period) | 2 | Until ADR-018 AC-027/AC-028 close |

## Guard Script

`scripts/qa/verify-legacy-ecommerce-ui-refs.sh` monitors for new legacy ecommerce references in branded surfaces.

## Related

- **ADR**: `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- **Spec**: `specs/ecommerce-purchase-gateway_spec.md`
- **Gateway**: `services/purchase-gateway/`
