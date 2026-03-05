# Mobile LMS OAuth2 and Branded App Configuration

> **Bead**: mereka-lms-mci9.1
> **ACs**: AC-MOB-PREP-001 through AC-MOB-PREP-004
> **Date**: 2026-02-19

---

## AC-MOB-PREP-001: OAuth2 Application Status

### Existing OAuth2 Applications (Live Cluster)

| Name | Grant Type | Redirect URIs |
|------|-----------|---------------|
| Login Service for JWT Cookies | password | (internal) |
| CMS/Studio SSO | authorization-code | `https://studio.academyv2.mereka.io/complete/edx-oauth2/` |
| Ecommerce SSO | authorization-code | `https://ecommerce.academyv2.mereka.io/complete/edx-oauth2/` |
| Discovery SSO | authorization-code | `https://discovery.academyv2.mereka.io/complete/edx-oauth2/` |
| Credentials SSO | authorization-code | `https://credentials.academyv2.mereka.io/complete/edx-oauth2/` |
| Enterprise Admin Portal SSO | authorization-code | `https://admin.academyv2.mereka.io/login/callback` |
| Enterprise Learner Portal SSO | authorization-code | `https://learner.academyv2.mereka.io/login/callback` |

### Mobile OAuth2 App Status: **NOT YET CREATED**

No mobile OAuth2 application exists in the LMS. The Open edX mobile app (edX for iOS/Android or custom Mereka mobile) requires a dedicated PKCE-capable OAuth2 app with deep-link redirect URIs.

### Required Mobile OAuth2 App (to be created)

```bash
# Create via LMS Django admin or management command:
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms --settings=tutor.production shell -c "
from oauth2_provider.models import Application
from django.contrib.auth import get_user_model
User = get_user_model()
admin = User.objects.filter(is_superuser=True).first()
app, created = Application.objects.get_or_create(
    name='Mereka Academy Mobile App',
    defaults={
        'client_type': 'public',
        'authorization_grant_type': 'authorization-code',
        'redirect_uris': 'org.openedx.mobile://oauth2/callback\nhttps://academyv2.mereka.io/oauth2/callback/mobile',
        'skip_authorization': True,
        'user': admin,
    }
)
print('Created:', created, '| Client ID:', app.client_id)
"
```

---

## AC-MOB-PREP-002: Deep-Link and Redirect URI Matrix

### Required Redirect URIs for Mobile App

| Platform | URI Scheme | Notes |
|----------|-----------|-------|
| Android | `org.openedx.mobile://oauth2/callback` | Standard Open edX Android scheme |
| iOS | `org.openedx.mobile://oauth2/callback` | Same scheme (universal link) |
| Custom Mereka | `mereka://oauth2/callback` | Optional branded scheme |
| Web fallback | `https://academyv2.mereka.io/oauth2/callback/mobile` | Browser fallback for auth |

### Deep-Link Domains (Android App Links / iOS Universal Links)

| Domain | Purpose |
|--------|---------|
| `academyv2.mereka.io` | Primary LMS domain |
| `apps.academyv2.mereka.io` | MFE domain (course viewer) |
| `academy.biji-biji.com` | Biji-Biji tenant |
| `skillourfuture.academy.mereka.io` | Skill Our Future tenant |

### PKCE Requirements

Open edX mobile apps use PKCE (Proof Key for Code Exchange) for public clients:
- `code_challenge_method`: `S256`
- No client secret required for public clients
- `client_type: public` in Django OAuth Toolkit

---

## AC-MOB-PREP-003: Branding Endpoints for Mobile Clients

### LMS Config Endpoints Used by Mobile

| Endpoint | URL | Notes |
|----------|-----|-------|
| LMS Config | `https://academyv2.mereka.io/api/mobile/v1/config/` | Returns platform name, logo, social links |
| OIDC Config | `https://academyv2.mereka.io/.well-known/openid-configuration` | Token endpoint, JWKS |
| Course List | `https://academyv2.mereka.io/api/mobile/v1/users/{username}/course_enrollments/` | User courses |

### Branding Config for Mobile

The LMS mobile API returns platform branding from `SiteConfiguration`:

```python
# Config exposed to mobile via /api/mobile/v1/config/:
{
  "platform_name": "Mereka Academy",      # from SiteConfiguration.platform_name
  "logo_image_url": "https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png",
  "favicon_url": "https://academyv2.mereka.io/static/mereka/images/favicon.ico",
}
```

All three tenants (MEREKA, BIJIBIJI, SKILLOURFUTURE) have matching SiteConfiguration entries in `infrastructure/tutor/multisite-sites.yml` with correct `logo_image` and `platform_name`.

---

## AC-MOB-PREP-004: Mobile Login + Token Exchange Smoke Test

### Pre-requisite: Mobile OAuth2 App Must Be Created (see AC-MOB-PREP-001)

```bash
# 1. Get client_id from the created mobile OAuth2 app
CLIENT_ID="<client_id_from_creation>"

# 2. Generate PKCE code_verifier and code_challenge
CODE_VERIFIER=$(python3 -c "import secrets,base64; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b'=').decode())")
CODE_CHALLENGE=$(python3 -c "import hashlib,base64,sys; v=sys.argv[1]; print(base64.urlsafe_b64encode(hashlib.sha256(v.encode()).digest()).rstrip(b'=').decode())" "$CODE_VERIFIER")

# 3. Authorization URL (open in browser or app):
echo "https://academyv2.mereka.io/oauth2/authorize/?response_type=code&client_id=${CLIENT_ID}&redirect_uri=org.openedx.mobile://oauth2/callback&scope=openid+email+profile&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

# 4. Exchange code for tokens:
curl -s -X POST https://academyv2.mereka.io/oauth2/access_token/ \
  -d "grant_type=authorization_code&code=<AUTH_CODE>&client_id=${CLIENT_ID}&redirect_uri=org.openedx.mobile://oauth2/callback&code_verifier=${CODE_VERIFIER}"

# Expected response:
# {"access_token": "...", "token_type": "Bearer", "expires_in": 3600,
#  "refresh_token": "...", "scope": "openid email profile"}

# 5. Verify token works:
curl -s -H "Authorization: Bearer <access_token>" \
  https://academyv2.mereka.io/api/user/v1/me
# Expected: {"username": "...", "email": "...", "name": "..."}
```

---

## Gap Summary

| AC | Status | Action Required |
|----|--------|----------------|
| AC-MOB-PREP-001 | ❌ NOT DONE | Create mobile OAuth2 app (command above) |
| AC-MOB-PREP-002 | ✅ DOCUMENTED | URI matrix complete; apply when creating app |
| AC-MOB-PREP-003 | ✅ PASS | Branding endpoints confirmed; SiteConfiguration correct for all 3 tenants |
| AC-MOB-PREP-004 | ⚠️ BLOCKED | Smoke test ready; requires OAuth2 app creation first |

**Single operator action**: Run the OAuth2 app creation command above, then run the token exchange smoke test.
