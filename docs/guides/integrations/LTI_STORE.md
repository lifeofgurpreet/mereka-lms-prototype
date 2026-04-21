# Reusable LTI Store Guide

_Audience: Platform Admins · Course Authors · Platform Engineers_
_Stack: Open edX Ulmo (Tutor 21.0.3)_
_Last verified: 2026-02-24_

---

## What is the Reusable LTI Store?

Open edX **Ulmo** (the release bundled with Tutor 21) introduced the **LTI Tool Store** — a
platform-wide registry of approved LTI tools that course authors can reuse without re-entering
credentials for each course.

Before the LTI Store, each course author had to paste LTI tool credentials (launch URL, consumer
key, shared secret, public key) individually into every course. This meant:

- Credentials duplicated across hundreds of courses
- Authors handling raw secrets
- No central governance over which tools are approved

The LTI Tool Store solves this by centralising approved tools in the Django admin. Authors pick
from a dropdown of pre-approved tools; credentials never leave the admin interface.

---

## Architecture

```
Platform Admin
  → Django admin: /admin/lti_consumer/ltitool/
  → Registers tool once (LtiTool model row in MySQL)

Course Author
  → Studio unit → Add LTI Consumer component
  → Selects pre-approved tool from dropdown
  → No credentials required

LMS (runtime)
  → Reads LtiTool from DB
  → Initiates OIDC login / OAuth 1.0 launch
  → Exposes JWKS at /api/lti_consumer/v1/public_keysets/<tool-id>/
```

The `LtiTool` Django model is part of the `lti_consumer` XBlock, which is bundled with Open edX
Ulmo. No extra installation is needed.

---

## Prerequisites

- Open edX Ulmo (Tutor 21.0.3+)
- `lti_consumer` XBlock in `INSTALLED_APPS` (bundled — no manual setup needed)
- Platform admin access to `/admin/lti_consumer/ltitool/`

Verify the XBlock is available:

```bash
# From a running LMS pod
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c \
  "from lti_consumer.models import LtiTool; print('LtiTool OK')"
```

---

## Adding a Tool to the LTI Store

### Step 1 — Gather credentials from the tool provider

For **LTI 1.3** (recommended):
- Tool Launch URL
- OIDC Login Initiation URL
- Tool Public Key (RSA, JWK or PEM) **or** Tool Keyset URL

For **LTI 1.1** (legacy):
- Launch URL
- Consumer Key
- Shared Secret

### Step 2 — Register the tool in Django admin

1. Go to `https://academyv2.mereka.io/admin/lti_consumer/ltitool/`
2. Click **Add LTI Tool**
3. Fill in:

| Field | Description |
|---|---|
| **Title** | Human-readable name shown in Studio dropdown (e.g., `Coding Lab – Mereka`) |
| **LTI 1.3 Tool Launch URL** | Provided by the tool vendor |
| **LTI 1.3 OIDC URL** | OIDC initiation URL from the vendor |
| **LTI 1.3 Public Key** | RSA public key (PEM) **or** leave blank if using Keyset URL |
| **LTI 1.3 Tool Keyset URL** | URL to the tool's JWKS endpoint (preferred over static key) |
| **Is active** | Enable to make visible to authors in Studio |

4. **Save**. Copy the generated **Client ID** — provide it to the tool vendor.

### Step 3 — Provide platform details to the tool vendor

| Setting | Value |
|---|---|
| **Platform OIDC Config URL** | `https://academyv2.mereka.io/.well-known/openid-configuration` |
| **Platform JWKS URL** | `https://academyv2.mereka.io/api/lti_consumer/v1/public_keysets/<tool-id>/` |
| **Client ID** | From Step 2 |
| **Deployment ID** | `1` (default for single-deployment setups) |

Replace `<tool-id>` with the numeric database ID shown in the Django admin URL after saving.

---

## How Tools Persist Across Course Contexts

The key architectural difference between the LTI Store and the legacy per-course passport approach:

| | Legacy (per-course passports) | LTI Store (Ulmo) |
|---|---|---|
| **Storage** | Course advanced settings (ModuleStore) | `LtiTool` table in MySQL |
| **Scope** | Per-course | Platform-wide |
| **Credentials visible to** | Course authors (in Studio Advanced Settings) | Platform admins only (Django admin) |
| **Tool update propagation** | Manual per-course | Immediate (all courses use the DB row) |
| **Key rotation** | Re-enter in every course | Update once in Django admin |

When a learner launches an LTI component:

1. The LMS reads the `LtiTool` DB row linked to that component (by `lti_1p3_tool_id`)
2. Builds the OIDC/OAuth request using the stored credentials
3. Signs the JWT using the platform's rotating RSA key (served from the JWKS endpoint)

The `LtiTool` row is referenced by ID, not by name, so renaming a tool in the admin does not
break existing course components.

---

## Author Workflow in Studio

Once a platform admin has registered tools in the LTI Store:

1. Open a course unit in Studio
2. Click **Advanced** → **LTI Consumer**
3. In the component editor:
   - Set **LTI Version** to `LTI 1.3`
   - Select the pre-approved tool from the **LTI Tool** dropdown
   - Configure grade passback settings if required
4. Save and publish

Authors do not need to handle credentials, keys, or client IDs. The dropdown is populated from
active `LtiTool` rows in the database.

For LTI 1.1 (legacy tools not yet migrated to LTI 1.3), the per-course passport approach
remains available via Studio Advanced Settings → **LTI Passports**.

---

## JWKS Endpoint

Open edX Ulmo manages LTI 1.3 signing keys automatically. Each registered tool has a dedicated
JWKS endpoint:

```
https://academyv2.mereka.io/api/lti_consumer/v1/public_keysets/<tool-id>/
```

- Keys rotate on a configurable schedule (default: automatic)
- Tool providers should always fetch the current keyset from this URL rather than
  caching a static public key
- No manual key rotation is required for LTI 1.3

To test the endpoint for a tool with ID `42`:

```bash
curl -s https://academyv2.mereka.io/api/lti_consumer/v1/public_keysets/42/ | python3 -m json.tool
```

Expected response: a JSON Web Key Set with one or more RSA keys.

---

## Configuration Requirements

The LTI Store works out of the box with Open edX Ulmo. No additional configuration patches are
required in `apply-patches.sh`.

Key platform settings (managed by Open edX base, not custom patches):

| Setting | Default | Notes |
|---|---|---|
| `lti_consumer` in `INSTALLED_APPS` | Yes (bundled) | Required for LtiTool model |
| `FEATURES['ENABLE_LTI_PROVIDER']` | `True` | Must not be explicitly set to `False` |
| LTI 1.3 key generation | Automatic | Keys stored in `LtiConfiguration` table |

To verify on a live cluster:

```bash
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
installed = any('lti_consumer' in a for a in settings.INSTALLED_APPS)
enabled = settings.FEATURES.get('ENABLE_LTI_PROVIDER', True)
print(f'lti_consumer installed: {installed}')
print(f'ENABLE_LTI_PROVIDER: {enabled}')
"
```

---

## Managing Tools

### Listing registered tools

```bash
# Via Django shell
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "
from lti_consumer.models import LtiTool
for t in LtiTool.objects.all():
    print(f'  [{t.id}] {t.title} - active={t.is_active}')
"
```

### Deactivating a tool

In Django admin, uncheck **Is active** on the `LtiTool` row. Existing course components will
stop showing the tool in the Studio dropdown, but launched LTI sessions that are already in
progress will continue until the session expires.

### Rotating a tool's credentials

For LTI 1.3:
1. Update the **LTI 1.3 Tool Keyset URL** or **LTI 1.3 Public Key** in Django admin
2. Notify the tool vendor of any client ID or platform JWKS URL changes

For LTI 1.1:
1. Generate a new shared secret
2. Update the `LtiTool` row in Django admin
3. Update the secret at the tool provider's side
4. Brief downtime is expected during the cutover window

---

## Relationship to the Base LTI Guide

This document covers the **LTI Store** (Ulmo's platform-wide tool registry). For:

- LTI 1.1 per-course passports
- LTI 1.3 per-course configurations (before using the Store)
- Grade passback (AGS / Basic Outcomes)
- Security considerations and key rotation
- SAML configuration alignment
- Troubleshooting

See **[docs/guides/integrations/LTI.md](LTI.md)** (created per T035).

---

## Verification

Run the automated verification script:

```bash
# Offline (repo checks only)
./scripts/qa/verify-lti-store.sh

# Online (also probes live cluster and endpoints)
./scripts/qa/verify-lti-store.sh --online
```

Expected result: all checks PASS or SKIP (no FAIL).

---

## Reference

- [Open edX LTI Consumer XBlock documentation](https://docs.openedx.org/en/latest/educators/how-tos/course_development/exercise_tools/lti.html)
- [IMS Global LTI 1.3 specification](https://www.imsglobal.org/spec/lti/v1p3/)
- [Tutor documentation](https://docs.tutor.edly.io/)
- LTI admin: `https://academyv2.mereka.io/admin/lti_consumer/ltitool/`
- Verification script: `scripts/qa/verify-lti-store.sh`
- Base LTI guide: `LTI.md`
