# MFE Login White Screen Fix

<!-- Last verified: 2026-02-13 -->

## Problem
Accessing `http://apps.localhost/authn/login` shows a white screen (404 error).

## Root Cause
1. The MFE Docker image (`openedx-mfe:nightly`) doesn't include the `authn` MFE - it only has `account`, `gradebook`, and `profile` built.
2. Caddy redirects `apps.localhost/` root to `http://localhost`, which may interfere with MFE routes.

## Quick Fix (Use LMS Login)

**Use the LMS login page directly instead:**
- **URL:** http://localhost/login
- **Credentials:** `admin` / `admin123`

This will work immediately and provide full login functionality.

## Long-term Fix

### Option 1: Rebuild MFE Image (Recommended)
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor images build mfe
tutor local restart mfe
```

**Note:** This requires a stable network connection as it downloads and builds all MFEs.

### Option 2: Use Dev MFEs
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor dev start mfe --detach
./scripts/branding/setup-mfe-branding.sh
cd tutor_env/dev/frontend-app-authn
npm install
npm start
```

This runs the authn MFE in development mode on a different port.

### Option 3: Fix Caddy Redirect
Modify the Caddyfile to exclude `/authn/*` paths from the redirect:

```caddyfile
apps.localhost{$default_site_port} {
    @not_mfe {
        path !/authn*
        path !/account*
        path !/profile*
        path !/learning*
    }
    redir @not_mfe / http://localhost
    request_body {
        max_size 2MB
    }
    import proxy "mfe:8002"
}
```

Then regenerate Caddy config:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate
tutor config save
tutor local restart caddy
```

## Current Status
- ✅ LMS login works: http://localhost/login
- ❌ MFE authn login broken: http://apps.localhost/authn/login (404)
- ✅ Other MFEs work: account, profile, gradebook

## Recommendation
**For now:** Use http://localhost/login for authentication.

**Later:** Rebuild the MFE image when you have time and stable network, or use dev mode for MFE development.

