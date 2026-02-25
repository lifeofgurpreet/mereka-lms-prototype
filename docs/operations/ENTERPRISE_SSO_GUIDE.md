# Enterprise SSO Guide

> **Spec**: `specs/auth-sso-enterprise_spec.md`
> **Status**: Phase 0 complete — infrastructure in place, no live enterprise IdP yet
> **Last updated**: 2026-02-25

---

## Overview

This guide documents the Enterprise SSO posture for Mereka Academy. It covers:

- What Phase 0 provides today (infrastructure foundation)
- What Phase 1 (full SSO) requires to be built
- Operator runbook for adding a new enterprise IdP

**Current auth architecture:**

```
Non-enterprise users  →  Authentik OIDC (auth0.mereka.io)  →  LMS
Enterprise users      →  [Phase 1: per-tenant SAML/OIDC]   →  LMS  (not live yet)
Platform admins       →  Authentik OIDC + MerekaPlatformAdminMiddleware
```

---

## Phase 0: What Is In Place Today

Phase 0 was completed as infrastructure groundwork. The following is present in the repo and deployed to production:

### Django App — `third_party_auth`

Open edX's native `third_party_auth` app handles SAML/OIDC federation. It is present in the LMS image by default in Open edX Ulmo (v21).

The `ENABLE_ENTERPRISE_INTEGRATION = True` flag is set in `infrastructure/tutor/plugins/mereka_lms.py`, which activates enterprise-related features in the LMS.

### SAML SP Key Pair Generation

```bash
# Generate a new SAML SP certificate and private key
./scripts/tenants/generate-saml-keypair.sh

# Write to files instead of stdout
./scripts/tenants/generate-saml-keypair.sh --output-dir /tmp/saml-keys

# Then store in Infisical:
# MEREKA_LMS_SAML_SP_PUBLIC_CERT
# MEREKA_LMS_SAML_SP_PRIVATE_KEY
```

Keys are RSA-2048, self-signed, 5-year validity. Enterprise IdPs typically prefer long-lived SP certs to avoid frequent metadata re-exchange.

### ExternalSecret — `enterprise-sso-secrets`

Defined in `deploy/k8s/base/secrets/external-secrets.yaml`. Syncs four secrets from GCP Secret Manager into K8s:

| K8s Secret Key | GCP Secret Manager Key | Purpose |
|---|---|---|
| `SAML_SP_PUBLIC_CERT` | `MEREKA_LMS_SAML_SP_PUBLIC_CERT` | SAML SP signing/encryption cert |
| `SAML_SP_PRIVATE_KEY` | `MEREKA_LMS_SAML_SP_PRIVATE_KEY` | SAML SP private key |
| `OIDC_ENTERPRISE_CLIENT_SECRET` | `MEREKA_LMS_OIDC_ENTERPRISE_CLIENT_SECRET` | Template OIDC client secret |
| `SCIM_BEARER_TOKEN` | `MEREKA_LMS_SCIM_BEARER_TOKEN` | SCIM provisioning bearer token |

**Status**: ExternalSecret definition exists. The GCP secrets themselves are NOT yet populated (keys have not been generated and stored yet).

### Feature Flag — `DISABLE_ENTERPRISE_LOGIN`

The authn MFE respects `MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"]`. This is currently `True` (enterprise login buttons hidden) in `mereka_lms.py`. Set to `False` when the first enterprise tenant is live.

### Tenant Tooling Scripts

| Script | Status | Purpose |
|---|---|---|
| `scripts/tenants/generate-saml-keypair.sh` | Ready | Generate SAML SP keypair |
| `scripts/tenants/configure-tenant-idp.sh` | Stub (TODO) | Wrap Django management commands to configure IdP |
| `scripts/tenants/provision-tenant.sh` | Ready | Provision enterprise tenant |

---

## Phase 1: What Must Be Built for Full SSO

The following are required to onboard the first enterprise IdP. They are defined as Acceptance Criteria in `specs/auth-sso-enterprise_spec.md` but not yet implemented.

### 1. Populate SAML Secrets (Operator Action)

Before any enterprise SSO can work, generate and store the SP keypair:

```bash
# 1. Generate
./scripts/tenants/generate-saml-keypair.sh --output-dir /tmp/saml-keys

# 2. Store in GCP Secret Manager (bbi-k8 project)
printf '%s' "$(cat /tmp/saml-keys/saml-sp-cert.pem)" | \
  gcloud secrets create MEREKA_LMS_SAML_SP_PUBLIC_CERT \
    --project bbi-k8 --data-file=-

printf '%s' "$(cat /tmp/saml-keys/saml-sp-key.pem)" | \
  gcloud secrets create MEREKA_LMS_SAML_SP_PRIVATE_KEY \
    --project bbi-k8 --data-file=-

# 3. ExternalSecrets will auto-sync to K8s within 1 hour, or force:
kubectl annotate externalsecret enterprise-sso-secrets \
  -n mereka-lms force-sync=$(date +%s) --overwrite

# 4. Confirm K8s secret exists
kubectl get secret enterprise-sso-secrets -n mereka-lms
```

### 2. Configure SAMLProviderConfig in Django Admin

For each enterprise tenant:

1. Log in to Django Admin: `https://academyv2.mereka.io/admin/`
2. Navigate to: **Third Party Auth > SAML Provider Configs > Add**
3. Fields to set:
   - **Site**: `academyv2.mereka.io`
   - **Backend name**: `tpa-saml`
   - **Enabled**: Yes
   - **Slug**: `{tenant-slug}` (e.g. `acme-corp`)
   - **Entity ID**: IdP entity ID from the enterprise IT team's metadata
   - **Metadata source**: URL or XML from the enterprise IT team
   - **Attribute mappings**: map `email`, `first_name`, `last_name` from IdP SAML attributes
   - **Automatic account linking**: Yes (for JIT provisioning)

4. Navigate to **Enterprise > Enterprise Customers**
5. Set `identity_provider` to the slug configured above

### 3. Link IdP to EnterpriseCustomer

```python
# Via Django shell (kubectl exec into LMS pod)
from enterprise.models import EnterpriseCustomer
ec = EnterpriseCustomer.objects.get(slug="acme-corp")
ec.identity_provider = "tpa-saml-acme-corp"  # third_party_auth slug
ec.save()
```

### 4. Implement `configure-tenant-idp.sh`

The script at `scripts/tenants/configure-tenant-idp.sh` is currently a TODO stub. It needs to wrap:
- `python manage.py lms create_or_update_saml_provider` (or equivalent management command)
- Django admin API calls for `EnterpriseCustomer.identity_provider` linkage

### 5. SP Metadata Endpoint

Once a `SAMLProviderConfig` exists, the LMS automatically serves SP metadata at:

```
https://academyv2.mereka.io/auth/saml/metadata.xml
```

Share this URL with the enterprise IT team. They configure it as the "Service Provider" in their IdP.

### 6. SCIM Provisioning Endpoint (Phase 3)

The SCIM bearer token is already in ExternalSecrets (`SCIM_BEARER_TOKEN`). However, the SCIM endpoint itself (`/scim/v2/`) requires either:
- The `openedx-scim` package (not yet installed)
- Or a custom FastAPI service similar to Purchase Gateway

This is gated behind `ENABLE_SCIM_PROVISIONING` feature flag.

---

## Operator Runbook: Adding a New Enterprise IdP

### Prerequisites

- [ ] Enterprise IT team has provided: IdP type (SAML or OIDC), metadata URL (SAML) or discovery endpoint (OIDC), configured Mereka SP entity ID in their IdP
- [ ] `enterprise-sso-secrets` K8s secret exists (SAML keypair is populated)
- [ ] `EnterpriseCustomer` record for the tenant exists in LMS (created by `./scripts/tenants/provision-tenant.sh`)
- [ ] Platform operator has Django admin access

### Step 1: Exchange Metadata (SAML)

**From the enterprise IT team, obtain:**
- IdP entity ID
- IdP SSO endpoint URL
- IdP signing certificate (or metadata URL)

**Provide to the enterprise IT team:**
- SP Entity ID: `https://academyv2.mereka.io/auth/saml/sp-metadata/{tenant-slug}` (or the global `/auth/saml/metadata.xml`)
- SP ACS URL: `https://academyv2.mereka.io/auth/complete/tpa-saml/?next=/`
- SP Certificate: contents of `SAML_SP_PUBLIC_CERT` from `enterprise-sso-secrets`

### Step 2: Create SAMLProviderConfig (SAML) or OAuth2ProviderConfig (OIDC)

Via Django Admin at `https://academyv2.mereka.io/admin/third_party_auth/`.

**For SAML:**
```
Backend name: tpa-saml
Slug: {tenant-slug}
Entity ID: {IdP entity ID from step 1}
Metadata source: {metadata URL or XML}
```

**For OIDC:**
```
Backend name: oidc-{tenant-slug}
Client ID: {from IdP OIDC app registration}
Client Secret: {store in GCP SM as MEREKA_LMS_OIDC_{TENANT_SLUG}_CLIENT_SECRET}
Authorization URL, Token URL, User Info URL: from IdP discovery endpoint
```

### Step 3: Link to EnterpriseCustomer

In Django Admin: **Enterprise > Enterprise Customers > {Tenant} > identity_provider**

Set to the slug created in Step 2.

### Step 4: Enable per-tenant Feature Flag

In LMS settings (via `bbi-infrastructure` overlay):
```python
ENABLE_ENTERPRISE_SSO_ACME_CORP = True
```

Or via Waffle flag if implemented.

### Step 5: Verify

```bash
# Run the verification script
./scripts/qa/verify-enterprise-sso-readiness.sh --tenant acme-corp --env prod

# Manually test the login URL
curl -L https://academyv2.mereka.io/enterprise/login/acme-corp
# Should redirect to the enterprise IdP login page
```

### Step 6: Enable Enterprise Login Buttons in MFE

Once the first enterprise tenant is confirmed working, toggle the feature flag:

```python
# In mereka_lms.py or bbi-infrastructure overlay
MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"] = False
```

---

## Dev Environment (rke2-nonprod / academyv2.mereka.dev)

The dev environment (rke2-nonprod cluster, `*.mereka.dev`) can be used to test enterprise SSO before production. Key differences:

- LMS URL: `https://academyv2.mereka.dev`
- SP metadata: `https://academyv2.mereka.dev/auth/saml/metadata.xml`
- ACS URL: `https://academyv2.mereka.dev/auth/complete/tpa-saml/`
- Dev ExternalSecret uses same `gcp-secret-manager` ClusterSecretStore, same `bbi-k8` GCP project

For testing without a real enterprise IdP, use a free SAML IdP simulator such as:
- [samltool.com](https://www.samltool.com/idp.php) (browser-based)
- [MockSAML](https://mocksaml.com/) (hosted test IdP)
- Authentik itself configured as a SAML IdP (Authentik supports SAML IdP mode)

---

## Security Notes

- **Do not reuse SP signing keys across tenants.** Each tenant should have a dedicated keypair. The current ExternalSecret stores one shared keypair; for production multi-tenant use, extend the ExternalSecret with per-tenant keys (e.g., `MEREKA_LMS_SAML_SP_KEY_ACME_CORP`).
- **SAML assertions with SHA-1 signatures MUST be rejected.** Open edX's `python-social-auth` rejects SHA-1 by default; do not override this.
- **Assertion replay prevention** is handled by `python-social-auth`'s Redis-backed assertion ID cache (TTL = assertion validity window). Confirm Redis is healthy before enabling enterprise SSO.
- **Cross-tenant isolation**: The `EnterpriseCustomer.identity_provider` field enforces which IdP can authenticate to which tenant. Never configure a shared IdP slug for multiple tenants.
- **SCIM bearer tokens** should be rotated annually per `docs/operations/SECRET_ROTATION_CHECKLIST.md`.

---

## Troubleshooting

### "Can't fetch setting of a disabled backend/provider"

The `OAuth2ProviderConfig` or `SAMLProviderConfig` for the site is disabled. In Django Admin, ensure `enabled=True` and `visible=True` on the latest config row.

### SAML ACS returns 500

Check LMS pod logs for SAML assertion errors:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i saml
```

Common causes:
- Clock skew > 120s between IdP and LMS server
- Missing or wrong SP entity ID in IdP configuration
- Assertion signed with SHA-1 (rejected)

### Enterprise login URL returns 404

The enterprise routing requires `openedx-enterprise` package and `ENABLE_ENTERPRISE_INTEGRATION=True`. Both are set. If 404 persists, confirm the URL path:
- Correct: `/enterprise/login/{slug}` (not `/auth/login/tpa-saml/{slug}`)

### JIT provisioning creates no user

Check that `ENABLE_THIRD_PARTY_AUTH=True` in LMS settings and that the `SAMLProviderConfig` has "Enable automatic account linking" checked. Also verify the SAML attribute mapping includes `email`.

### `enterprise-sso-secrets` K8s secret is missing

The GCP secrets have not been populated yet. Follow Step 1 in "Phase 1: What Must Be Built". Run:
```bash
kubectl get externalsecret enterprise-sso-secrets -n mereka-lms -o yaml | grep -A5 "status:"
```

A `SecretSyncedError` condition indicates the GCP secret does not exist.

---

## Related Files

| File | Purpose |
|---|---|
| `specs/auth-sso-enterprise_spec.md` | Machine-checkable spec with 45 ACs |
| `infrastructure/tutor/plugins/mereka_lms.py` | Plugin: `ENABLE_ENTERPRISE_INTEGRATION`, `DISABLE_ENTERPRISE_LOGIN` |
| `deploy/k8s/base/secrets/external-secrets.yaml` | `enterprise-sso-secrets` ExternalSecret definition |
| `scripts/tenants/generate-saml-keypair.sh` | SAML SP keypair generator |
| `scripts/tenants/configure-tenant-idp.sh` | IdP configuration helper (TODO stub) |
| `scripts/tenants/provision-tenant.sh` | Create EnterpriseCustomer + TenantConfig |
| `scripts/qa/verify-enterprise-sso-readiness.sh` | Phase 0 SSO readiness verification (auth-sso-enterprise_spec.md AC-043) |
| `scripts/qa/verify-enterprise-sso.sh` | Enterprise integrated channels verification (enterprise-microservices_spec.md Phase 4) |
| `scripts/qa/verify-auth-hardening.sh` | Full auth hardening suite runner |
| `docs/operations/AUTH_HARDENING_SPEC.md` | Auth hardening decisions and implementation |
| `docs/operations/AUTH_AND_PERMISSIONS.md` | Permissions model documentation |
| `docs/operations/RFC_CLAIM_BASED_ROLE_SYNC.md` | RFC for IdP claim → role mapping |
