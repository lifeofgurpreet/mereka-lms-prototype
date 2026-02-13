# Mobile OAuth Provisioning Runbook

<!-- Last verified: 2026-02-13 -->

This document covers creating and managing OAuth2 applications in Open edX for mobile app authentication.

## Overview

Open edX uses Django OAuth Toolkit (DOT) for OAuth2 authentication. Mobile apps require a DOT application to authenticate users via OAuth2.

**Flow**:
1. Mobile app redirects to `/oauth2/authorize`
2. User logs in (if not already authenticated)
3. User grants permission
4. Server redirects to app with authorization code
5. App exchanges code for access token
6. App uses token to access `/api/user/v1/me` and other endpoints

## Creating OAuth Applications

### Using `create_dot_application` Command

**Command**:
```bash
tutor local exec lms ./manage.py lms create_dot_application \
  --grant-type authorization-code \
  --redirect-uris "merekaacademy://oauth" \
  --client-id "mereka-mobile-ios" \
  --client-name "Mereka Academy iOS" \
  --scopes "user_id email profile read write" \
  --skip-authorization \
  --update
```

**Parameters**:
- `--grant-type`: OAuth2 grant type (typically `authorization-code` for mobile)
- `--redirect-uris`: Deep link URI for mobile app (e.g., `merekaacademy://oauth`)
- `--client-id`: Unique identifier for the application
- `--client-name`: Human-readable name
- `--scopes`: Permission scopes (see below)
- `--skip-authorization`: Skip consent screen for first-party apps
- `--update`: Update existing application if client-id exists

### Production Command

```bash
# SSH into LMS pod
kubectl exec -it -n mereka-lms deploy/lms -- bash

# Run command
./manage.py lms create_dot_application \
  --grant-type authorization-code \
  --redirect-uris "merekaacademy://oauth" \
  --client-id "mereka-mobile-ios-prod" \
  --client-name "Mereka Academy iOS (Production)" \
  --scopes "user_id email profile read write" \
  --skip-authorization \
  --update
```

### Dev Configuration

For development/testing:

```bash
# Local kind cluster
tutor local exec lms ./manage.py lms create_dot_application \
  --grant-type authorization-code \
  --redirect-uris "merekaacademy://oauth" \
  --client-id "mereka-mobile-ios-dev" \
  --client-name "Mereka Academy iOS (Dev)" \
  --scopes "user_id email profile read write" \
  --skip-authorization \
  --update
```

**Dev-specific settings**:
- Use separate `client-id` (e.g., `-dev` suffix)
- Test with localhost or staging URLs
- Can use HTTP for redirect URIs (not HTTPS)

## Required Scopes

OAuth scopes determine what data/endpoints the mobile app can access:

| Scope | Purpose |
|-------|---------|
| `user_id` | Access user ID |
| `email` | Access user email address |
| `profile` | Access user profile (name, username, avatar) |
| `read` | Read access to LMS data (courses, enrollments) |
| `write` | Write access (enroll in courses, submit assignments) |

**Minimal scopes for mobile**: `user_id email profile`

**Full access**: `user_id email profile read write`

## Prod vs Dev Configuration

### Production
- **Domain**: `academyv2.mereka.io`
- **Redirect URI**: `merekaacademy://oauth` (production deep link)
- **Client ID**: `mereka-mobile-ios-prod`
- **HTTPS only**: Enforce secure connections
- **Skip authorization**: Yes (first-party app)

### Dev/Staging
- **Domain**: `academy-dev.mereka.io` or `localhost`
- **Redirect URI**: `merekaacademy-dev://oauth` (dev deep link)
- **Client ID**: `mereka-mobile-ios-dev`
- **HTTP allowed**: For local testing
- **Skip authorization**: Yes

## Verification: Test Login Contract

### 1. Authorization Endpoint

Test OAuth2 authorization flow:

```bash
# Build authorization URL
AUTH_URL="https://academyv2.mereka.io/oauth2/authorize"
CLIENT_ID="mereka-mobile-ios-prod"
REDIRECT_URI="merekaacademy://oauth"
RESPONSE_TYPE="code"
SCOPE="user_id email profile"

# Full URL
echo "$AUTH_URL?client_id=$CLIENT_ID&redirect_uri=$REDIRECT_URI&response_type=$RESPONSE_TYPE&scope=$SCOPE"
```

**Expected**: Redirects to login page (if not authenticated) or consent page

### 2. Token Exchange

Exchange authorization code for access token:

```bash
# After receiving code from redirect
CODE="<authorization-code>"
CLIENT_ID="mereka-mobile-ios-prod"
CLIENT_SECRET="<client-secret>"  # From DOT application
REDIRECT_URI="merekaacademy://oauth"

curl -X POST https://academyv2.mereka.io/oauth2/access_token \
  -d "grant_type=authorization_code" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$CODE" \
  -d "redirect_uri=$REDIRECT_URI"
```

**Expected Response**:
```json
{
  "access_token": "<access-token>",
  "token_type": "Bearer",
  "expires_in": 36000,
  "refresh_token": "<refresh-token>",
  "scope": "user_id email profile"
}
```

### 3. User Profile Endpoint

Test access token by fetching user profile:

```bash
ACCESS_TOKEN="<access-token>"

curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  https://academyv2.mereka.io/api/user/v1/me
```

**Expected Response**:
```json
{
  "id": 123,
  "username": "testuser",
  "email": "testuser@example.com",
  "name": "Test User",
  "profile_image": {
    "image_url_full": "https://...",
    "image_url_medium": "https://...",
    "image_url_small": "https://..."
  }
}
```

## Managing OAuth Applications

### List Applications

```bash
# Django shell
tutor local exec lms ./manage.py lms shell

>>> from oauth2_provider.models import Application
>>> apps = Application.objects.all()
>>> for app in apps:
...     print(f"{app.client_id}: {app.name}")
```

### Update Application

Use `--update` flag to modify existing application:

```bash
tutor local exec lms ./manage.py lms create_dot_application \
  --client-id "mereka-mobile-ios" \
  --scopes "user_id email profile read write" \
  --update
```

### Delete Application

```bash
# Django shell
tutor local exec lms ./manage.py lms shell

>>> from oauth2_provider.models import Application
>>> app = Application.objects.get(client_id="mereka-mobile-ios-dev")
>>> app.delete()
```

## Troubleshooting

### "Invalid client_id" Error

**Cause**: Application not created or client_id mismatch

**Fix**:
```bash
# Verify application exists
tutor local exec lms ./manage.py lms shell
>>> from oauth2_provider.models import Application
>>> Application.objects.filter(client_id="mereka-mobile-ios").exists()
```

### "Redirect URI mismatch" Error

**Cause**: Redirect URI in request doesn't match registered URI

**Fix**: Update application redirect URI:
```bash
tutor local exec lms ./manage.py lms create_dot_application \
  --client-id "mereka-mobile-ios" \
  --redirect-uris "merekaacademy://oauth,merekaacademy-dev://oauth" \
  --update
```

### "Invalid scope" Error

**Cause**: Requested scope not in allowed scopes

**Fix**: Update application scopes:
```bash
tutor local exec lms ./manage.py lms create_dot_application \
  --client-id "mereka-mobile-ios" \
  --scopes "user_id email profile read write" \
  --update
```

## Security Best Practices

1. **Use HTTPS in production**: Never use HTTP for OAuth flows
2. **Store client_secret securely**: Use iOS Keychain or Android KeyStore
3. **Rotate secrets regularly**: Update client_secret quarterly
4. **Validate redirect URIs**: Only allow registered deep links
5. **Use PKCE**: For public clients (mobile apps), use PKCE extension
6. **Limit scopes**: Request only necessary scopes

## Related Documentation

- `docs/MOBILE_IOS_APP_SETUP.md` - iOS app setup guide
- `docs/operations/AUTH_AND_PERMISSIONS.md` - Authentication architecture
- [Django OAuth Toolkit Documentation](https://django-oauth-toolkit.readthedocs.io/)
