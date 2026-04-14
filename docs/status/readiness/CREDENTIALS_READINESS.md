# Credentials + Learner Record MFE — Production Readiness Audit

**Audit date**: 2026-02-25
**Tracker task**: T123
**Status**: PARTIAL — infrastructure complete, operator actions required before public use

---

## Summary

| Area | State | Notes |
|---|---|---|
| Credentials service deployment | READY | Deployment, Service, ingress all present |
| Caddy proxy (credentials subdomain) | READY | `credentials.academyv2.mereka.io` route present in Caddyfile |
| Credentials settings (production.py) | READY | Mereka-customised settings in ConfigMap |
| Credentials secrets (ExternalSecrets) | READY | 5 secrets mapped from `bbi-k8` GCP SM |
| VC issuer custom app (did:web) | READY | Installed via Tutor plugin, DID endpoint wired |
| VC signing key provisioned | UNKNOWN | `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` must be verified in GCP SM |
| LMS → Credentials service URL | READY | `CREDENTIALS_INTERNAL_SERVICE_URL` defaults correct |
| OAuth2 client keys registered in LMS | UNKNOWN | `credentials-key` and `credentials-key-sso` must be registered as DOT apps |
| DB migrations run | UNKNOWN | `credentials` MySQL DB must exist and migrations applied |
| **learner-record MFE — Caddyfile route** | **READY** | `/learner-record` block is present in the MFE Caddyfile |
| learner-record MFE — Dockerfile build | READY | Built from `release/ulmo.1`, dist copied to `/openedx/dist/learner-record` |
| learner-record MFE — settings pointer | READY | `LEARNER_RECORD_MFE_RECORDS_PAGE_URL` set in production.py |
| Badge/cert issuance — LMS wiring | READY | `CREDENTIALS_INTERNAL_SERVICE_URL` / `CREDENTIALS_PUBLIC_SERVICE_URL` set |
| Monitoring (PrometheusRule) | READY | `credentials-alerts` PrometheusRule deployed |

---

## What Is Enabled

### Credentials Service

- **Deployment**: `deploy/k8s/base/apps/credentials/deployment.yaml` — `overhangio/openedx-credentials:21.0.0` at port 8000
- **Service**: `deploy/k8s/base/apps/credentials/service.yaml` — NodePort 8000, selector `app.kubernetes.io/name: credentials`
- **Ingress**: `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` — `credentials.academyv2.mereka.io` → Caddy port 80, TLS via Let's Encrypt
- **Caddy proxy block**: `deploy/k8s/base/apps/caddy/Caddyfile` lines 213–243 — `http://credentials.academyv2.mereka.io` → `credentials:8000`, with `/authn/*` and `/admin/login` re-routed through MFE

### Mereka Settings Customisations

`deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py` sets:

- `USE_LEARNER_RECORD_MFE = True`
- `ENABLE_VERIFIABLE_CREDENTIALS = True`
- `LEARNER_RECORD_MFE_RECORDS_PAGE_URL = "https://apps.academyv2.mereka.io/learner-record/"`
- `VERIFIABLE_CREDENTIALS` dict: `ISSUER_DID`, `SIGNATURE_SUITE = Ed25519Signature2020`, `SIGNING_KEY_ID`
- `SOCIAL_AUTH_EDX_OAUTH2_*` — SSO OAuth2 from LMS
- `BACKEND_SERVICE_EDX_OAUTH2_*` — service-to-service OAuth2
- `MerekaPlatformAdminMiddleware` — admin login hardening

Development settings (`development.py`) differ: `ENABLE_VERIFIABLE_CREDENTIALS = False` (safe default).

### Verifiable Credentials Issuer (VC Issuer)

Custom Django app at `infrastructure/tutor/custom-apps/credentials_vc_issuer/`:

- Installed into the credentials Docker image via `mereka_lms.py` Tutor plugin hook
  (`credentials-dockerfile-post-python-requirements`)
- URL pattern wired via `credentials-urlpatterns` hook:
  `path('', include('credentials_vc_issuer.urls'))`
- Serves `/.well-known/did.json` — DID document for W3C Verifiable Credentials
- Derives Ed25519 public key from `VC_SIGNING_PRIVATE_KEY` env var at request time
- DID method: `did:web:credentials.academyv2.mereka.io`

### ExternalSecrets Mapped

All five credentials secrets are mapped from `bbi-k8` GCP Secret Manager:

| Secret (K8s env key) | GCP Secret Manager key |
|---|---|
| `CREDENTIALS_SECRET_KEY` | `MEREKA_LMS_CREDENTIALS_SECRET_KEY` |
| `CREDENTIALS_BACKEND_OAUTH2_SECRET` | `MEREKA_LMS_CREDENTIALS_BACKEND_OAUTH2_SECRET` |
| `CREDENTIALS_SSO_OAUTH2_SECRET` | `MEREKA_LMS_CREDENTIALS_SSO_OAUTH2_SECRET` |
| `JWT_SECRET_KEY_CREDENTIALS` | `MEREKA_LMS_JWT_SECRET_KEY_CREDENTIALS` |
| `VC_SIGNING_PRIVATE_KEY` | `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` |

Database password `MYSQL_CREDENTIALS_PASSWORD` is in `database-secrets` (separate ExternalSecret).

### LMS → Credentials Wiring

`deploy/k8s/base/apps/openedx/settings/lms/production.py`:

```
CREDENTIALS_INTERNAL_SERVICE_URL = os.environ.get(
    "CREDENTIALS_INTERNAL_SERVICE_URL", MEREKA_CREDENTIALS_BASE_URL
)  # → https://credentials.academyv2.mereka.io
CREDENTIALS_PUBLIC_SERVICE_URL  → same
CREDENTIALS_SERVICE_USERNAME = "credentials"
```

### Learner Record MFE — Build

`infrastructure/tutor/mfe-build/Dockerfile` line 913:

```
COPY --from=learner-record-prod /openedx/app/dist /openedx/dist/learner-record
```

The MFE is built from `frontend-app-learner-record` at `release/ulmo.1` and its production bundle
is copied into `/openedx/dist/learner-record` inside the MFE image. `PUBLIC_PATH=/learner-record/`.

### Monitoring

`deploy/k8s/base/monitoring/prometheusrule-credentials.yaml` — `credentials-alerts` PrometheusRule with 6 alerting rules:

- `VCIssuanceLatencyHigh`
- `VCIssuanceFailureSpike`
- `VCClaimTokenExpiryHigh`
- `VCVerificationEndpointDown`
- `VCDIDDocumentUnavailable`
- `VCSigningKeyExpiringSoon`

---

## What Is Missing / Gaps

### Gap 1: learner-record Caddyfile Route (historical, now resolved)

**File**: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`

The earlier audit identified a missing learner-record route in the MFE Caddyfile. That is no
longer true on the current source baseline.

Current source now contains:
- the learner-record build output in `infrastructure/tutor/mfe-build/Dockerfile`
- `LEARNER_RECORD_MICROFRONTEND_URL` in LMS settings
- the `/learner-record` Caddyfile route in `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`

This row should now be treated as closed source debt. Runtime/browser proof of the current
route remains a separate validation concern.

```caddy
@mfe_learner-record {
    path /learner-record /learner-record/*
}
handle @mfe_learner-record {
    uri strip_prefix /learner-record
    root * /openedx/dist/learner-record
    try_files /{path} /index.html
    file_server
}
```

### Gap 2: VC Signing Key — Needs Verification

`MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` must exist in GCP Secret Manager (`bbi-k8` project) and
contain a valid base64-encoded Ed25519 private key (64 bytes).

If the key is absent or malformed:
- The `credentials_vc_issuer` app logs a warning and returns HTTP 500 on `/.well-known/did.json`
- `ENABLE_VERIFIABLE_CREDENTIALS` is forced to `False` by the settings guard
- Verifiable credential issuance silently fails without surfacing the root cause to learners

**Verify**:

```bash
cd ../reka-slackbot  # or wherever reka-slackbot is checked out
infisical secrets get MEREKA_LMS_VC_SIGNING_PRIVATE_KEY \
  --domain https://secrets.mereka.io/api \
  --env prod --path / --plain 2>/dev/null | wc -c
# Should be >0 (non-empty)
```

**Generate** (if absent):

```bash
python3 -c "
import base64, os
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives.serialization import Encoding, PrivateFormat, NoEncryption
priv = ed25519.Ed25519PrivateKey.generate()
raw = priv.private_bytes(Encoding.Raw, PrivateFormat.Raw, NoEncryption())
pub = priv.public_key().public_bytes(Encoding.Raw, ed25519.Ed25519PublicKey.public_bytes.__doc__ and __import__('cryptography').hazmat.primitives.serialization.PublicFormat.Raw)
# Full 64-byte key: seed + public
full = raw + priv.public_key().public_bytes(Encoding.Raw, __import__('cryptography').hazmat.primitives.serialization.PublicFormat.Raw)
print(base64.b64encode(full).decode())
"
```

Store the output in Infisical as `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY`, then sync to GCP SM.
See `docs/ops/runbooks/credential-key-rotation-runbook.md` for the full procedure.

### Gap 3: OAuth2 Client Applications Not Verified in LMS

The Credentials service authenticates to the LMS via two OAuth2 clients:

| Client | Key | Purpose |
|---|---|---|
| SSO client | `credentials-key-sso` | Learner SSO login into Credentials service |
| Backend client | `credentials-key` | Service-to-service API calls |

These DOT (Django OAuth Toolkit) applications must be registered in the LMS Django admin:
`https://academyv2.mereka.io/admin/oauth2_provider/application/`

If absent, learners cannot log in to `credentials.academyv2.mereka.io` and LMS → Credentials
API calls will fail with 401.

**Verify**:

```bash
kubectl exec -n mereka-lms \
  "$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')" \
  -- python manage.py lms shell -c "
from oauth2_provider.models import Application
for key in ['credentials-key-sso', 'credentials-key']:
    exists = Application.objects.filter(client_id=key).exists()
    print(f'{key}: {\"OK\" if exists else \"MISSING\"}')"
```

### Gap 4: Database Migrations Status Unknown

The `credentials` MySQL database must exist and migrations must have been applied.

**Verify**:

```bash
kubectl exec -n mereka-lms \
  "$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=credentials -o jsonpath='{.items[0].metadata.name}')" \
  -- python manage.py showmigrations --list | grep -c "\[X\]"
# Should be >0
```

**Apply** (if migrations not run):

```bash
kubectl exec -n mereka-lms \
  "$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=credentials -o jsonpath='{.items[0].metadata.name}')" \
  -- python manage.py migrate
```

### Gap 5: Badge/Certificate Templates Not Verified

Open edX requires at least one certificate template to be configured for the Credentials service
to issue certificates. These are managed via the Django admin at
`https://credentials.academyv2.mereka.io/admin/credentials/certificatetemplate/`.

If no templates exist, the certificate issuance pipeline will silently produce no credentials
for learners who complete courses.

---

## Operator Actions Required

The following actions must be completed (in order) before credentials and learner records are
usable in production:

### Action 1: Add learner-record Caddyfile route (BLOCKER)

Edit `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` — add the `@mfe_learner-record` block
shown in Gap 1 above, following the same pattern as the `@mfe_learner-dashboard` block (line 127).

After merging to main, ArgoCD will reconcile and restart the MFE pod automatically.

### Action 2: Provision VC Signing Key

If `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` does not exist in GCP SM (`bbi-k8` project):

1. Generate an Ed25519 keypair (see Gap 2 above)
2. Store in Infisical: `infisical secrets set MEREKA_LMS_VC_SIGNING_PRIVATE_KEY="<base64-key>" ...`
3. Sync to GCP SM: `gcloud secrets create MEREKA_LMS_VC_SIGNING_PRIVATE_KEY --project=bbi-k8 ...`
4. Wait for ExternalSecret to sync (up to 1 hour, or force: `kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=$(date +%s)`)
5. Verify: `curl https://credentials.academyv2.mereka.io/.well-known/did.json | jq .`

### Action 3: Register OAuth2 Clients in LMS

Via Django admin at `https://academyv2.mereka.io/admin/oauth2_provider/application/`:

Register two applications:
- `credentials-key-sso` — Client Type: Confidential, Grant Type: Authorization Code
  - Client secret must match `MEREKA_LMS_CREDENTIALS_SSO_OAUTH2_SECRET` in GCP SM
- `credentials-key` — Client Type: Confidential, Grant Type: Client Credentials
  - Client secret must match `MEREKA_LMS_CREDENTIALS_BACKEND_OAUTH2_SECRET` in GCP SM

### Action 4: Run DB Migrations

```bash
kubectl exec -n mereka-lms \
  "$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=credentials -o jsonpath='{.items[0].metadata.name}')" \
  -- python manage.py migrate
```

### Action 5: Create Certificate Template

Log in to `https://credentials.academyv2.mereka.io/admin/` and create at least one
`CertificateTemplate` linked to the Mereka Academy organisation.

---

## Verification

Run the readiness check script to confirm infrastructure state:

```bash
./scripts/qa/verify-credentials-readiness.sh
```

For live cluster checks (requires `kubectl` access):

```bash
./scripts/qa/verify-credentials-readiness.sh --cluster
```

---

## Related Files

| File | Purpose |
|---|---|
| `deploy/k8s/base/apps/credentials/deployment.yaml` | Credentials Deployment manifest |
| `deploy/k8s/base/apps/credentials/service.yaml` | Credentials Service (NodePort 8000) |
| `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` | Ingress for `credentials.academyv2.mereka.io` |
| `deploy/k8s/base/apps/caddy/Caddyfile` | Caddy proxy block for credentials subdomain |
| `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | MFE Caddyfile — learner-record route present |
| `deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py` | Mereka production settings |
| `deploy/k8s/base/secrets/external-secrets.yaml` | Credentials secret mappings |
| `infrastructure/tutor/custom-apps/credentials_vc_issuer/` | VC issuer custom Django app |
| `infrastructure/tutor/plugins/mereka_lms.py` | Tutor plugin hooks (install, URL wiring) |
| `infrastructure/tutor/mfe-build/Dockerfile` | MFE build — learner-record at line 733 |
| `deploy/k8s/base/monitoring/prometheusrule-credentials.yaml` | Alerting rules |
| `docs/ops/runbooks/credential-key-rotation-runbook.md` | Key rotation procedure |
| `docs/ops/runbooks/credential-issuance-failure-runbook.md` | Issuance failure runbook |
| `specs/verifiable-credentials-issuer_spec.md` | Spec: VC issuer (CRED-020) |
| `specs/verifiable-credentials-issuance_spec.md` | Spec: issuance flows (CRED-030) |
