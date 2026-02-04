# Ecommerce OAuth 500 Troubleshooting
_Audience: Platform Eng • Last updated: 2026-02-04_

Use this checklist when Ecommerce returns `500` during login or API calls. The most common cause is a mismatch between the LMS OAuth2 client config and the Ecommerce settings.

## ✅ Expected OAuth Clients in LMS

Create (or verify) **two** OAuth2 applications in LMS admin:

1. **Backend service client**
   - **Client ID**: `ecommerce` (or `ECOMMERCE_BACKEND_OAUTH2_KEY`)
   - **Client secret**: matches `MEREKA_LMS_ECOMMERCE_BACKEND_OAUTH2_SECRET`
   - **Redirect URIs**:
     - `https://ecommerce.academyv2.mereka.io/complete/edx-oauth2/`
     - `https://ecommerce.academyv2.mereka.dev/complete/edx-oauth2/` (dev)

2. **SSO client**
   - **Client ID**: `ecommerce-sso` (or `ECOMMERCE_OAUTH2_KEY`)
   - **Client secret**: matches `MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET`
   - **Redirect URIs**:
     - `https://ecommerce.academyv2.mereka.io/complete/edx-oauth2/`
     - `https://ecommerce.academyv2.mereka.dev/complete/edx-oauth2/` (dev)

> Ensure the **backend** client ID and secret are distinct from the **SSO** client.

## ✅ Ecommerce Settings (K8s)

`deploy/k8s/base/plugins/ecommerce/apps/ecommerce/settings/production.py` must keep the backend key aligned with the backend OAuth2 client:

- `BACKEND_SERVICE_EDX_OAUTH2_KEY = ECOMMERCE_BACKEND_OAUTH2_KEY`
- `BACKEND_SERVICE_EDX_OAUTH2_SECRET = ECOMMERCE_BACKEND_OAUTH2_SECRET`
- `SOCIAL_AUTH_EDX_OAUTH2_KEY = ECOMMERCE_OAUTH2_KEY`
- `SOCIAL_AUTH_EDX_OAUTH2_SECRET = ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET`

## ✅ Secrets (Infisical → GCP → ExternalSecrets)

Ensure these exist in **Infisical** under `/k8s/mereka-lms` for **prod + dev**:

- `MEREKA_LMS_ECOMMERCE_BACKEND_OAUTH2_SECRET`
- `MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET`
- `MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE`

Then confirm ExternalSecrets sync:

```bash
kubectl describe externalsecret openedx-secrets -n mereka-lms
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.ECOMMERCE_BACKEND_OAUTH2_SECRET}'
```

## ✅ Verify

```bash
curl -I https://ecommerce.academyv2.mereka.io/dashboard/
kubectl logs -n mereka-lms deployment/ecommerce --tail=100
```

If the logs show OAuth client errors, re-check client IDs, secrets, and redirect URIs.
