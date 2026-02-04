# MFE OAuth Fix

This custom Django app fixes the issue where the `/api/mfe_context` endpoint returns an empty `providers` array even when OAuth providers are properly configured in the database.

## Problem

The `/api/mfe_context` endpoint exists and returns HTTP 200, but the `providers` array in `contextData` is empty:

```json
{
  "contextData": {
    "providers": []
  }
}
```

However, the database shows OAuth providers exist and are enabled:
- Site ID: 6 (academyv2.mereka.io)
- Provider: Authentik (displayed as “Mereka”)
- enabled=True, visible=True

## Solution

This app provides a middleware (`MFEOAuthFixMiddleware`) that:
1. Intercepts responses from `/api/mfe_context`
2. Checks if the `providers` array is empty
3. Queries the database directly for OAuth providers for the current site
4. Injects the providers into the response

## Components

- `middleware.py` - Django middleware that fixes the response
- `views.py` - Alternative view implementation (not currently used, middleware is simpler)
- `apps.py` - Django app configuration
- `urls.py` - URL patterns (not currently used, middleware is simpler)
- `setup.py` - Package configuration

## Installation

The app is automatically installed and configured via the `apply-patches.sh` script:

1. Custom app code is copied to `/openedx/mfe_oauth_fix` in the Docker image
2. App is added to `INSTALLED_APPS` in LMS production settings
3. Middleware is added to `MIDDLEWARE` stack

## Testing

After deploying:

```bash
# Test the endpoint
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
```

Expected output:
```json
[
  {
    "id": "oa2-authentik",
    "name": "Mereka",
    "loginUrl": "/auth/login/oauth2-authentik/?auth_entry=login&next=/dashboard",
    "registerUrl": "/auth/login/oauth2-authentik/?auth_entry=register&next=/dashboard"
  }
]
```

## Logging

The middleware logs to the Django logger at INFO level:
- When it detects an empty providers array
- Current site information
- Number of providers found
- Each provider added to the response

Check logs with:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep mfe_oauth_fix
```

## Future Improvements

1. Once the root cause in the Open edX platform is identified, this middleware can be removed
2. The alternative `views.py` implementation can be used if a full endpoint replacement is preferred
3. Consider contributing the fix upstream to Open edX if it's a platform bug
