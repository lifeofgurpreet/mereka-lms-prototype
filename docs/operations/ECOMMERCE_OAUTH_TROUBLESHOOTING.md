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

**Quick verification (no secrets)**
```bash
kubectl exec -n mereka-lms deploy/lms -- \
  python /openedx/edx-platform/manage.py lms shell -c \
  "from oauth2_provider.models import Application; \
print([(a.name,a.client_id,a.redirect_uris) for a in Application.objects.filter(name__in=['Ecommerce Backend Service','Ecommerce SSO'])])"
```

If the `manage.py` checks fail with MySQL `1045 Access denied`, see
`docs/operations/TROUBLESHOOTING.md` (Issue 4d). The most common cause is a
trailing newline in `OPENEDX_MYSQL_PASSWORD` from the secret store.

## ✅ OAuth Scopes (ApplicationAccess)

Ecommerce requests `user_id profile email`. The LMS uses **ApplicationAccess** to
grant extra scopes per client. If the entry is missing, Ecommerce returns
`invalid_scope` and `/complete/edx-oauth2/` throws a 500.

**Verify scopes**
```bash
cat <<'PY' | kubectl exec -i -n mereka-lms deploy/lms -- python -
import django
django.setup()
from openedx.core.djangoapps.oauth_dispatch.models import ApplicationAccess
from oauth2_provider.models import Application
for client_id in ["ecommerce-sso", "ecommerce"]:
    app = Application.objects.filter(client_id=client_id).first()
    access = ApplicationAccess.objects.filter(application=app).first()
    print(client_id, access.scopes if access else None)
PY
```

**Fix scopes (adds `user_id`)**
```bash
cat <<'PY' | kubectl exec -i -n mereka-lms deploy/lms -- python -
import django
django.setup()
from openedx.core.djangoapps.oauth_dispatch.models import ApplicationAccess
from oauth2_provider.models import Application
for client_id in ["ecommerce-sso", "ecommerce"]:
    app = Application.objects.filter(client_id=client_id).first()
    access, created = ApplicationAccess.objects.get_or_create(
        application=app,
        defaults={"scopes": ["user_id"]},
    )
    if not created and (not access.scopes or "user_id" not in access.scopes):
        access.scopes = sorted(set((access.scopes or []) + ["user_id"]))
        access.save()
    print(client_id, access.scopes)
PY
```

## ✅ Ecommerce SiteConfiguration + Partner

Ecommerce will return `500` if the **SiteConfiguration** or **Partner** rows are missing.

Verify in Ecommerce admin:

- **Sites** includes:
  - `ecommerce.academyv2.mereka.io` (prod)
  - `ecommerce.academyv2.mereka.dev` (dev)
  - `ecommerce.localhost` (local)
- **SiteConfiguration** exists for each site and sets:
  - `lms_url_root` → `https://academyv2.mereka.io` (prod) / `https://academyv2.mereka.dev` (dev)
  - `payment_processors` → `cybersource,paypal`
- **Partner** exists with:
  - `code`: `mereka`
  - `short_code`: `mereka`
  - `default_site`: `ecommerce.academyv2.mereka.io`

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
- `MEREKA_LMS_STRIPE_PUBLISHABLE_KEY` (if enabling Stripe)
- `MEREKA_LMS_STRIPE_SECRET_KEY` (if enabling Stripe)
- `MEREKA_LMS_STRIPE_WEBHOOK_SECRET` (optional until webhooks are configured)

**Dev key separation (kind):** both prod and dev clusters read from the same
GCP Secret Manager project (`bbi-k8`), so dev Stripe values are stored as
separate secrets:

- `MEREKA_LMS_STRIPE_SECRET_KEY_DEV`
- `MEREKA_LMS_STRIPE_PUBLISHABLE_KEY_DEV`
- `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_DEV`

Dev uses a full ExternalSecret patch (not a partial list) to avoid accidentally
blanking required secrets:

- `deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml`

Then confirm ExternalSecrets sync:

```bash
kubectl describe externalsecret openedx-secrets -n mereka-lms
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.ECOMMERCE_BACKEND_OAUTH2_SECRET}'
```

If Stripe is enabled, update the Ecommerce **SiteConfiguration** `payment_processors`
field to include `stripe` (e.g. `cybersource,paypal,stripe`) after the secrets are
in place.

Finally, restart Ecommerce to pick up updated env vars:

```bash
kubectl rollout restart deploy/ecommerce deploy/ecommerce-worker -n mereka-lms
kubectl --context kind-dev rollout restart deploy/ecommerce deploy/ecommerce-worker -n mereka-lms
```

## ✅ Verify

```bash
./scripts/qa/verify-ecommerce-config.sh
K8S_CONTEXT=kind-dev ./scripts/qa/verify-ecommerce-config.sh
curl -I https://ecommerce.academyv2.mereka.io/dashboard/
kubectl logs -n mereka-lms deployment/ecommerce --tail=100
```

`verify-ecommerce-config.sh` reports whether Stripe env vars are present and
whether the webhook secret is set (without printing any secret values). It also
prints the **key type** (`test`/`live`/`unknown`) so you can confirm:

- **Prod (GKE)** should use `live` keys.
- **Dev (kind)** should use `test` keys.

Note: Stripe webhook signing secrets are always `whsec_...` and do not encode
test/live in the prefix. The script reports webhook secret type as `set`.

To enforce that webhooks are configured before declaring “checkout ready”, run:

```bash
REQUIRE_STRIPE_WEBHOOK_SECRET=1 ./scripts/qa/verify-ecommerce-config.sh
REQUIRE_STRIPE_WEBHOOK_SECRET=1 K8S_CONTEXT=kind-dev ./scripts/qa/verify-ecommerce-config.sh
```

Webhook can remain unset until you configure Stripe webhooks, but **real payment
flows will not be reliable without webhooks**.

For a full setup guide, see:
- `docs/operations/STRIPE_WEBHOOKS_SETUP.md`

If the logs show OAuth client errors, re-check client IDs, secrets, and redirect URIs.

## ✅ Status (2026-02-04)
- OAuth clients exist in LMS with expected IDs and redirect URIs for `academyv2.mereka.io` + `academyv2.mereka.dev`.
- Ecommerce secrets are injected into the deployment and match LMS OAuth client secrets.
- Client-credentials token check returned `200` from both GKE and VPS kind.
- No 500s observed in recent logs; still re-test with a real login flow if users report errors.
