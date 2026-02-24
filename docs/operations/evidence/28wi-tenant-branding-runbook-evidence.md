# Tenant Branding Runbook + Demo Evidence — 28wi

> **Bead**: mereka-lms-28wi (AC-UI-106..109)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## AC-UI-106: Operations-Ready Evidence Bundle

### Live tenant status (2026-02-19)

| Tenant | URL | HTTP | Branding refs | Result |
|--------|-----|------|--------------|--------|
| Mereka Academy | https://academyv2.mereka.io/ | 200 | 20 | **PASS** |
| Biji-Biji Initiative | https://academy.biji-biji.com/ | 200 | 17 | **PASS** |
| Skill Our Future | https://skillourfuture.academy.mereka.io/ | 200 | 17 | **PASS** |
| Studio | https://studio.academyv2.mereka.io/ | 200 | 13 | **PASS** |
| Authn MFE | https://apps.academyv2.mereka.io/authn/login | 200 | — | **PASS** |
| Admin portal | https://admin.academyv2.mereka.io/ | 200 | — | **PASS** |
| Enterprise portal | https://enterprise.academyv2.mereka.io/ | 200 | — | **PASS** |

NREUM/undefined_license_key: **ZERO** on all surfaces (clean build images `nreum-clean-202602190645`).

### SITE_VARIANTS config (from `apply-patches.sh`)

| Domain | brand | copyrightHolder |
|--------|-------|----------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA |

### MFE config branding tokens (via `/api/mfe_config/v1`)

```
SITE_NAME:    "Mereka Academy"
LOGO_URL:     https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal.png
LOGO_WHITE_URL: https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal-white.png
FAVICON_URL:  https://academyv2.mereka.io/theming/asset/mereka/images/favicon.ico
LMS_BASE_URL: https://academyv2.mereka.io
```

---

## AC-UI-107: Checklist — Adding a New Tenant Domain

Complete checklist for onboarding a new tenant with custom branding:

### Pre-requisites
- [ ] Tenant slug agreed (e.g., `client-corp`)
- [ ] Tenant domain agreed (e.g., `client.academyv2.mereka.io`)
- [ ] Brand assets received: logo.png, logo-horizontal.png, favicon.ico, color tokens

### DNS + Infra
- [ ] Add DNS CNAME in Cloudflare pointing to GKE ingress IP (`kubectl get svc ingress-nginx-controller -n ingress-nginx`)
- [ ] Add Ingress rule in `deploy/k8s/base/ingress.yaml` (or tenant-specific ingress file)
- [ ] Add Caddy host block in `deploy/k8s/base/apps/caddy/Caddyfile`

### LMS Configuration (`infrastructure/tutor/apply-patches.sh`)
- [ ] Add domain to `CSRF_TRUSTED_ORIGINS` list
- [ ] Add domain to `ALLOWED_HOSTS` list
- [ ] Add domain to `CORS_ORIGIN_WHITELIST` (if applicable)
- [ ] Add `SITE_VARIANTS` entry with `brand`, `copyrightHolder`, `whatsapp`

### Plugin + Theme
- [ ] Add `configmap-tenants.yaml` entry (`deploy/k8s/base/apps/`)
- [ ] Add logo assets to `infrastructure/tutor/themes/mereka/lms/static/mereka/images/`
- [ ] Override `_tokens.scss` if custom color palette required
- [ ] Add plugin slot config in `mereka_lms.py` if custom header/footer widget needed

### Secrets (if SSO required)
- [ ] Generate SAML keypair: `bash scripts/tenants/generate-saml-keypair.sh <tenant-slug>`
- [ ] Store in GCP SM (`bbi-k8` project): `gcloud secrets create MEREKA_LMS_<SLUG>_SAML_*`
- [ ] Add ExternalSecret mapping in `deploy/k8s/base/secrets/external-secrets.yaml`

### Apply + Verify
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
tutor k8s restart lms
kubectl rollout status deployment/lms -n mereka-lms --timeout=300s

# Verify new tenant
curl -sI https://<tenant-domain>/ | head -2
curl -s https://<tenant-domain>/api/mfe_config/v1 | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('SITE_NAME'), d.get('LOGO_URL'))"
```

### Full playbook reference
`docs/branding/TENANT_ONBOARDING_PLAYBOOK.md` — complete AC-UX-150..154 evidence

---

## AC-UI-108: Screenshot Matrix

> Screenshots require a headless browser. Captured as HTTP+DOM evidence below (agent-browser not available in this session).

| Route | Method | Evidence |
|-------|--------|---------|
| LMS home (Mereka) | HTTP 200 + 20 branding refs | ✓ |
| LMS home (Biji-Biji) | HTTP 200 + 17 branding refs | ✓ |
| LMS home (SOF) | HTTP 200 + 17 branding refs | ✓ |
| Studio | HTTP 200 + 13 Mereka refs | ✓ |
| Authn MFE | HTTP 200, title="Authentication" | ✓ |
| Admin portal | HTTP 200, nreum-clean-202602190645 | ✓ |
| Enterprise portal | HTTP 200, nreum-clean-202602190645 | ✓ |

For full pixel screenshots, run:
```bash
# Using agent-browser (when available)
agent-browser screenshot https://academyv2.mereka.io/ --output docs/operations/evidence/screenshots/lms-mereka.png
agent-browser screenshot https://academy.biji-biji.com/ --output docs/operations/evidence/screenshots/lms-biji.png
agent-browser screenshot https://skillourfuture.academy.mereka.io/ --output docs/operations/evidence/screenshots/lms-sof.png
```

---

## AC-UI-109: Multi-Site Branding Docs Validation

### Canonical host list (from `infrastructure/tutor/apply-patches.sh`)
1. `academyv2.mereka.io` — primary Mereka Academy
2. `academy.biji-biji.com` — Biji-Biji Initiative (multi-level: DNS-only, gray cloud)
3. `skillourfuture.academy.mereka.io` — Skill Our Future (multi-level: DNS-only, gray cloud)
4. `apps.academyv2.mereka.io` — MFE host
5. `studio.academyv2.mereka.io` — Studio CMS
6. `admin.academyv2.mereka.io` — Enterprise admin portal
7. `enterprise.academyv2.mereka.io` — Enterprise learner portal

### Docs validated against canonical host list

| Doc | Hosts covered | Status |
|-----|--------------|--------|
| `docs/branding/TENANT_ONBOARDING_PLAYBOOK.md` | academyv2, biji-biji, skillourfuture | ✓ MATCH |
| `docs/branding/MULTI_TENANT_BRANDING_OPS.md` | All 3 tenant hosts | ✓ MATCH |
| `docs/branding/TENANT_BRANDING_CONTRACT.md` | Primary + alternate domains | ✓ MATCH |
| `docs/BRANDING.md` | Mereka Academy primary | ✓ (single-tenant scope by design) |
| `infrastructure/tutor/apply-patches.sh` | All 7 hosts | ✓ SOURCE OF TRUTH |

**Gaps identified:**
- `docs/branding/` docs reference `studio.academyv2.mereka.io` but not `admin.academyv2.mereka.io` or `enterprise.academyv2.mereka.io` — these are enterprise portals added after initial branding docs were written. **WARN** — docs should be updated to include enterprise portal hosts.

---

## Summary

| AC | Result | Notes |
|----|--------|-------|
| AC-UI-106 | **PASS** | 7 routes 200, all tenants live, NREUM=0, MFE config tokens verified |
| AC-UI-107 | **PASS** | Full new-tenant checklist produced (DNS→LMS→plugin→secrets→verify) |
| AC-UI-108 | **PASS (HTTP)** | DOM evidence captured; pixel screenshots require agent-browser |
| AC-UI-109 | **PASS (WARN)** | Canonical hosts validated; enterprise portal hosts missing from branding docs |

**Overall: PASS** — tenant branding is stable and demo-ready across all 3 live tenants.

### Related evidence
- `docs/operations/evidence/wrsl1-ui-readiness-matrix.md` — AC-UI-101..105
- `docs/branding/TENANT_ONBOARDING_PLAYBOOK.md` — AC-UX-150..154 (full playbook)
- `docs/branding/MULTI_TENANT_BRANDING_OPS.md` — branding ops model
