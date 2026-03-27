# MFE OAuth Provider Fix

## Quick Start

**Problem**: `/api/mfe_context` returns empty `providers` array even though OAuth providers exist in database.

**Solution**: Custom Django middleware that intercepts the response and injects OAuth providers.

**Status**: ✅ Implementation complete, ready for deployment

## For Deployment Team

Start here: **[MFE_OAUTH_FIX_CHECKLIST.md](./MFE_OAUTH_FIX_CHECKLIST.md)** - Step-by-step deployment checklist

## Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| **[MFE_OAUTH_FIX_CHECKLIST.md](./MFE_OAUTH_FIX_CHECKLIST.md)** | Step-by-step deployment checklist | DevOps/Deployment |
| **[MFE_OAUTH_FIX_SUMMARY.md](./MFE_OAUTH_FIX_SUMMARY.md)** | Technical overview and architecture | Technical leads |
| **[docs/ops/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](../ops/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)** | Detailed deployment guide with troubleshooting | DevOps/SRE |
| **[infrastructure/tutor/custom-apps/mfe_oauth_fix/README.md](../../infrastructure/tutor/custom-apps/mfe_oauth_fix/README.md)** | Custom app documentation | Developers |

## Quick Reference

### Test the Fix
```bash
./scripts/qa/test-mfe-oauth-fix.sh
```

### Deploy (High-Level)
```bash
# 1. Apply patches
./infrastructure/tutor/apply-patches.sh

# 2. Rebuild image (30-45 minutes)
tutor images build openedx

# 3. Deploy to K8s
# (see checklist for details)
```

### Verify
```bash
# Should return non-empty array with Authentik provider
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
```

## What Was Changed

### New Files Created

```
infrastructure/tutor/custom-apps/mfe_oauth_fix/
├── __init__.py           - App initialization
├── apps.py               - Django app config
├── middleware.py         - Core fix logic ⭐
├── views.py              - Alternative implementation (unused)
├── urls.py               - URL patterns (unused)
├── setup.py              - Package config
└── README.md             - App documentation

scripts/qa/
└── test-mfe-oauth-fix.sh - Automated test script ⭐

docs/operations/
└── MFE_OAUTH_FIX_DEPLOYMENT.md - Deployment guide

MFE_OAUTH_FIX_CHECKLIST.md    - Deployment checklist ⭐
MFE_OAUTH_FIX_SUMMARY.md       - Technical summary
MFE_OAUTH_FIX_README.md        - This file
```

### Modified Files

```
infrastructure/tutor/apply-patches.sh
├── Added Dockerfile patching to copy custom app
├── Added INSTALLED_APPS configuration
└── Added MIDDLEWARE configuration
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  MFE Login Page                                         │
│  GET /api/mfe_context                                   │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  LMS Django Application                                 │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Default /api/mfe_context endpoint               │   │
│  │ (Returns empty providers array due to bug)      │   │
│  └──────────────────┬──────────────────────────────┘   │
│                     │                                    │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │ MFEOAuthFixMiddleware (OUR FIX)                 │   │
│  │ 1. Detects empty providers array                │   │
│  │ 2. Queries OAuth2ProviderConfig from DB        │   │
│  │ 3. Injects providers into response              │   │
│  └──────────────────┬──────────────────────────────┘   │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  Response with Authentik provider                       │
│  {                                                      │
│    "contextData": {                                     │
│      "providers": [{                                    │
│        "id": "oa2-authentik",                          │
│        "name": "Authentik",                            │
│        "loginUrl": "/auth/login/oauth2-authentik/..."  │
│      }]                                                 │
│    }                                                    │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
```

## Key Features

✅ **Non-invasive** - Doesn't modify Open edX platform code
✅ **Targeted** - Only affects `/api/mfe_context` endpoint
✅ **Safe** - Only activates when providers array is empty
✅ **Observable** - Extensive logging for debugging
✅ **Reversible** - Easy rollback if needed
✅ **Tested** - Includes automated test script

## Risk Assessment

**Risk Level**: Low

- Changes are isolated to custom middleware
- Only modifies response when providers array is empty
- No database writes or platform code changes
- Easy to disable or rollback
- Extensive logging for monitoring

## Performance Impact

**Minimal** - Adds one database query per `/api/mfe_context` request

- Endpoint is only called during login/registration flow (low frequency)
- Query is filtered and uses indexed fields
- Can add caching if needed in future

## Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **Patches** | 1 minute | Apply patches script |
| **Build** | 30-45 min | Rebuild Open edX image |
| **Push** | 5 minutes | Push to registry |
| **Deploy** | 5 minutes | Apply to K8s |
| **Verify** | 5 minutes | Test and verify |
| **Total** | ~45-60 min | Full deployment |

## Next Steps

1. **Review** the [deployment checklist](./MFE_OAUTH_FIX_CHECKLIST.md)
2. **Schedule** deployment window (recommend non-peak hours)
3. **Prepare** rollback plan (previous image tag)
4. **Execute** deployment following checklist
5. **Monitor** for 24 hours post-deployment
6. **Investigate** upstream root cause (future work)

## Support

### During Deployment
- Follow [MFE_OAUTH_FIX_CHECKLIST.md](./MFE_OAUTH_FIX_CHECKLIST.md)
- Check logs: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms`

### Troubleshooting
- See [docs/ops/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](../ops/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- Check "Troubleshooting" section in deployment guide

### Rollback
```bash
# Quick rollback to previous image
kubectl set image deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<previous-tag> \
  -n mereka-lms
```

## Future Work

1. **Investigate** why default Open edX endpoint filters out providers
2. **Contribute** fix upstream to Open edX project
3. **Remove** this middleware once platform bug is fixed
4. **Add caching** if performance becomes an issue (unlikely)

---

**Implementation Date**: 2025-02-04
**Implemented By**: Claude Code (Sonnet 4.5)
**Status**: ✅ Ready for deployment
**Approval Required**: DevOps lead review recommended before production deployment
