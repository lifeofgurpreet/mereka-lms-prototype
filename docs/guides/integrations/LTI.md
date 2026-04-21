# LTI Integration Guide

_Audience: Course Authors · Platform Engineers · Site Operators_
_Stack: Open edX Ulmo (Tutor 21.0.4) · LTI 1.1 + LTI 1.3_
_Last verified: 2026-02-24_

---

## What is LTI?

**Learning Tools Interoperability (LTI)** is an IMS Global standard that lets external learning tools (simulations, assessments, video players, code sandboxes, proctoring systems) embed inside an LMS and exchange grades back. Open edX acts as the **LTI Platform** (consumer); external tools act as **LTI Tools** (providers).

Mereka uses LTI to:

- Embed third-party simulations and labs inside course units
- Pass learner grades from external tools back to the gradebook
- Integrate enterprise proctoring providers (future)
- Surface content from Mereka's own microservices as embeddable tools

---

## LTI 1.1 vs LTI 1.3

| Feature | LTI 1.1 | LTI 1.3 |
|---|---|---|
| Auth | Shared secret (OAuth 1.0) | JWT / OIDC (OAuth 2.0) |
| Grade passback | Basic Outcomes (XML) | Assignment and Grade Services (REST) |
| Security | Shared secret = plaintext risk | Signed JWTs, rotating keys |
| Deep linking | Not supported | Supported (LTI 1.3 + DL 2.0) |
| Ulmo support | Yes (legacy) | Yes (preferred) |

**Use LTI 1.3 for all new integrations.** LTI 1.1 remains available for tools that have not yet upgraded.

---

## Prerequisites

The `lti_consumer` XBlock is bundled with Open edX Ulmo. It is registered in `INSTALLED_APPS` via the base platform settings. No additional installation is needed for Mereka Academy.

Verify the XBlock is available:

```bash
# From a running LMS pod
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c \
  "from lti_consumer.models import LtiConfiguration; print('lti_consumer OK')"
```

---

## LTI 1.1: Adding an External Tool in Studio

### Step 1 — Obtain credentials from the tool provider

The tool provider must give you:
- **Launch URL** (e.g., `https://tool.example.com/lti/launch`)
- **Consumer Key** (acts as a username)
- **Shared Secret** (acts as a password — treat as a secret)

### Step 2 — Add an LTI Passport

LTI 1.1 credentials are registered as **LTI Passports** in Studio's advanced settings. Each passport has the format:

```
<passport-id>:<consumer-key>:<shared-secret>
```

In Studio:
1. Open the course → Settings → Advanced Settings
2. Find **LTI Passports**
3. Add an entry: `["my-tool:my-consumer-key:my-shared-secret"]`
4. Save

> Never hardcode secrets in course XML exports. The passport is stored in the database, not the course tarball.

### Step 3 — Enable LTI Advanced Component

In Studio → Advanced Settings → **Advanced Module List**, add `lti`.

### Step 4 — Add an LTI Component to a Unit

1. In a unit, click **Advanced** → **LTI Consumer**
2. Set **LTI ID** to the passport ID from Step 2
3. Set **LTI URL** to the launch URL
4. Configure **Open in New Page** or embedded, as required by the tool

---

## LTI 1.3: Adding an External Tool in Studio

LTI 1.3 uses the **LTI Configuration** model (Django admin + Studio UI). Credentials are per-configuration, not stored in a shared passport list.

### Step 1 — Gather tool credentials

The tool provider must give you:
- **Tool Launch URL**
- **Tool OIDC Login Initiation URL**
- **Tool Public Key** (RSA public key in JWK or PEM format)
- **Tool Keyset URL** (alternative to static public key)

### Step 2 — Register the LTI Tool in LMS Django admin

1. Go to `https://academyv2.mereka.io/admin/lti_consumer/ltitool/`
2. Click **Add LTI Tool**
3. Fill in:
   - **Title**: descriptive name (e.g., "Coding Lab")
   - **LTI 1.3 Tool Launch URL**
   - **LTI 1.3 OIDC URL**
   - **LTI 1.3 Public Key** or **LTI 1.3 Tool Keyset URL**
4. Save and copy the generated **Client ID**

### Step 3 — Configure the tool's side

Provide the tool provider with:
- **Platform OIDC Config URL**: `https://academyv2.mereka.io/.well-known/openid-configuration`
- **Platform JWKS URL**: `https://academyv2.mereka.io/api/lti_consumer/v1/public_keysets/<tool-id>/`
- **Client ID** (from Step 2)
- **Deployment ID**: `1` (default for single-deployment setups)

### Step 4 — Add the LTI Component to a Unit

In Studio, add an **LTI Consumer** component:
1. Select **LTI Version**: `LTI 1.3`
2. Select the registered tool from the **LTI Tool** dropdown
3. Configure **Launch URL** and grade passback settings

---

## Reusable LTI Store (Ulmo Feature)

Open edX Ulmo introduces the **LTI Tool Store** — a platform-wide registry of approved LTI tools that course authors can reuse without re-entering credentials.

**Why this matters for Mereka:**

- Platform admins approve and manage tool credentials centrally
- Course authors pick tools from a catalog without handling secrets
- Consistent configuration across all courses

**Admin setup:**

```
/admin/lti_consumer/ltitool/  →  Add tools once, reuse platform-wide
```

**Author workflow:**

In Studio → unit → LTI Consumer → select from pre-approved tools in the dropdown.

This is the recommended pattern for Mereka. Store all recurring tools (proctoring, labs, simulations) in the LTI Tool Store rather than per-course passports.

---

## Grade Passback

### LTI 1.1 — Basic Outcomes

The tool posts an XML score to `https://academyv2.mereka.io/courses/<course-id>/xblock/<usage-id>/handler/grade_handler`.

Enable in the LTI component:
- **Has Score**: Yes
- **Weight**: numeric (contributes to course grade)

### LTI 1.3 — Assignment and Grade Services (AGS)

AGS is enabled automatically when the LTI 1.3 component is configured with grading. The platform exposes:

```
/api/lti_consumer/v1/lti/<usage-id>/scores/
/api/lti_consumer/v1/lti/<usage-id>/results/
```

The tool must request the `https://purl.imsglobal.org/spec/lti-ags/scope/score` scope in its launch request.

---

## Security Considerations

### LTI 1.1 Key Rotation

1. Generate a new shared secret
2. Update the LTI Passport in Studio Advanced Settings
3. Update the secret at the tool provider side
4. Remove the old passport entry
5. There is no zero-downtime rotation for LTI 1.1; coordinate a brief maintenance window with the tool provider

### LTI 1.3 Key Rotation

Open edX Ulmo automatically rotates LTI 1.3 JWK signing keys on a configurable schedule. Keys are served from the public JWKS endpoint — the tool provider fetches the current keyset automatically.

No manual intervention is required for routine LTI 1.3 key rotation.

### TLS Requirements

LTI launch URLs **must** use HTTPS in production. Open edX will reject LTI launches over HTTP in production mode (`DEBUG=False`). Confirm:

```bash
# Tool launch URL must begin with https://
curl -I https://academyv2.mereka.io/api/lti_consumer/v1/lti/
```

### iframe Content Security Policy

LTI tools embedded in iframes must be allowlisted in the LMS Content Security Policy. Add tool domains to `X_FRAME_OPTIONS` exceptions if the tool reports being blocked by CSP.

---

## SAML Configuration Alignment

The Mereka LMS has SAML Service Provider (SP) infrastructure configured alongside LTI. These are orthogonal features (SAML is for user SSO; LTI is for tool embedding) but share the same `third_party_auth` Django app.

**Current SAML SP configuration (production):**

| Setting | Location | Value |
|---|---|---|
| `SOCIAL_AUTH_SAML_SP_PUBLIC_CERT` | `enterprise-sso-secrets` K8s secret | PEM cert from Infisical `MEREKA_LMS_SAML_SP_PUBLIC_CERT` |
| `SOCIAL_AUTH_SAML_SP_PRIVATE_KEY` | `enterprise-sso-secrets` K8s secret | PEM key from Infisical `MEREKA_LMS_SAML_SP_PRIVATE_KEY` |
| `SOCIAL_AUTH_SAML_SP_ENTITY_ID` | `production.py` → env `SAML_SP_ENTITY_ID` | Defaults to LMS base URL |
| SAML metadata endpoint | Built into Open edX | `/auth/saml/metadata.xml` |

**Generating a SAML keypair (if rotating):**

```bash
./scripts/tenants/generate-saml-keypair.sh
# Outputs: saml-sp.crt, saml-sp.key
# Upload to Infisical: MEREKA_LMS_SAML_SP_PUBLIC_CERT, MEREKA_LMS_SAML_SP_PRIVATE_KEY
# ExternalSecret syncs automatically within 1 hour (or force sync via ArgoCD)
```

**Verifying SAML metadata is live:**

```bash
curl -sI https://academyv2.mereka.io/auth/saml/metadata.xml | head -3
# Expected: HTTP/2 200
```

---

## Troubleshooting

### LTI Launch Fails (401 Unauthorized)

**LTI 1.1:** Consumer key or shared secret is wrong. Re-check the LTI Passport entry in Studio Advanced Settings. Keys are case-sensitive.

**LTI 1.3:** OIDC login flow failed. Check:
1. The tool's OIDC initiation URL is correct in Django admin
2. The tool's redirect URI is allowlisted on the tool side
3. LMS JWKS endpoint is accessible from the tool's server: `curl https://academyv2.mereka.io/api/lti_consumer/v1/public_keysets/<id>/`

### Grade Passback Not Working

**LTI 1.1:** Confirm the component has **Has Score** enabled and **Weight** > 0. Check LMS logs:

```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=200 | grep -i "lti\|grade_handler"
```

**LTI 1.3:** Confirm the tool requested the AGS scope. The tool provider's documentation will specify what scopes they support.

### Tool Loads in Broken iframe

The tool domain may be blocked by CSP. Check the browser console for CSP errors. Add the tool's domain to the `CRUM_ALLOWED_REDIRECT_HOSTS` or `X_FRAME_OPTIONS` configuration if needed.

### "LTI Component not available" in Studio

The `lti` string is missing from the **Advanced Module List**. In Studio → Advanced Settings → Advanced Module List, add `"lti"` to the JSON array.

### SAML Metadata Returns 404 or 500

1. Confirm `third_party_auth` is in `INSTALLED_APPS`:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- \
     python manage.py lms shell -c \
     "from django.conf import settings; print(any('third_party_auth' in a for a in settings.INSTALLED_APPS))"
   ```
2. Confirm `ENABLE_THIRD_PARTY_AUTH = True` in production settings
3. Check `enterprise-sso-secrets` K8s secret exists and has non-empty values:
   ```bash
   kubectl get secret enterprise-sso-secrets -n mereka-lms -o jsonpath='{.data.SAML_SP_PUBLIC_CERT}' | base64 -d | head -1
   ```

---

## Reference

- [Open edX LTI Consumer XBlock documentation](https://docs.openedx.org/en/latest/educators/how-tos/course_development/exercise_tools/lti.html)
- [IMS Global LTI 1.3 specification](https://www.imsglobal.org/spec/lti/v1p3/)
- [Tutor LTI configuration guide](https://docs.tutor.edly.io/)
- SAML keypair generation: `scripts/tenants/generate-saml-keypair.sh`
- SAML ExternalSecret: `deploy/k8s/base/secrets/external-secrets.yaml` (search `enterprise-sso-secrets`)
- LTI + SAML config verification: `scripts/qa/verify-lti-saml-config.sh`
