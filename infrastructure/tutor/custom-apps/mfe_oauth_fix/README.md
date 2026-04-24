# MFE OAuth Fix

This custom Django app fixes the issue where the `/api/mfe_context` endpoint returns an empty `providers` array even when OAuth providers are properly configured in the database. It also normalizes Authentik's display name to **“Mereka”** when providers are already present.

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

Additionally, when the provider is returned with the default name (e.g., `Authentik`), we want the UI to display **“Mereka”** instead.

## Solution

This app now has a split ownership model:
1. `MFEContextView` is the primary owner for the `/api/mfe_context` URL override
2. The view queries OAuth providers for the current site and returns the final JSON payload
3. The view marks its response with `X-MFE-OAuth-Fix-Source: view`
4. `MFEOAuthFixMiddleware` acts only as a fallback for responses that were not produced by the view override
5. The middleware still normalizes Authentik provider names to **“Mereka”** and can repopulate an empty providers array when the stock endpoint is still in play

## Components

- `constants.py` - Shared response ownership markers
- `middleware.py` - Fallback response fixer for non-view-owned `/api/mfe_context` responses
- `views.py` - Canonical `/api/mfe_context` URL override implementation
- `apps.py` - Django app configuration
- `urls.py` - URL override that routes `/api/mfe_context` to `MFEContextView`
- `setup.py` - Package configuration

## Installation

The app is automatically installed and configured via the `apply-patches.sh` script:

1. Custom app code is copied to `/openedx/mfe_oauth_fix` in the Docker image
2. App is added to `INSTALLED_APPS` in LMS production settings
3. URL override is added to `ROOT_URLCONF_OVERRIDES`
4. Middleware is added to `MIDDLEWARE` as a fallback path

For the Kubernetes deployment, make sure the LMS production settings configmap includes the same additions in `deploy/k8s/base/apps/openedx/settings/lms/production.py`. The configmap mounts into `/openedx/edx-platform/lms/envs/tutor/production.py`.

## Testing

After deploying:

```bash
# Test the endpoint
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'

# Or run the helper script
./scripts/qa/test-mfe-oauth-fix.sh
```

Expected output:
```json
[
  {
    "id": "oa2-oidc",
    "name": "Mereka",
    "loginUrl": "/auth/login/oidc/?auth_entry=login&next=/learner-dashboard/",
    "registerUrl": "/auth/login/oidc/?auth_entry=register&next=/learner-dashboard/"
  }
]
```

## Logging

The view logs:
- the current site
- the number of providers returned
- each provider added to the response

The middleware logs:
- when it detects an empty providers array on a non-view-owned response
- current site information for the fallback path
- number of providers found in the fallback path
- each provider added to the fallback response

Check logs with:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep mfe_oauth_fix
```

## Future Improvements

1. Once the root cause in the Open edX platform is identified, the fallback middleware can be removed
2. If URL override ownership is ever retired, keep an explicit contract describing whether the stock endpoint or this app owns provider population
3. Consider contributing the fix upstream to Open edX if it's a platform bug
