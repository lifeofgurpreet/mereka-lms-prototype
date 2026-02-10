# Alternative Domain Branding Fix - README

## Quick Start

To deploy the fix for academy.biji-biji.com branding issue:

```bash
# 1. Test dry-run (safe, no changes)
./scripts/infra/apply-multisite-config.sh --dry-run

# 2. Apply the fix
./scripts/infra/apply-multisite-config.sh --apply

# 3. Restart LMS pods
kubectl rollout restart deployment/lms -n mereka-lms

# 4. Verify
# Visit: https://academy.biji-biji.com
# Should now show "Mereka Academy" branding
```

## Documentation

### For Quick Deployment
- **DEPLOY_BRANDING_FIX.md** - Step-by-step deployment guide with commands

### For Understanding the Fix
- **ALTERNATIVE_DOMAIN_FIX_SUMMARY.md** - Complete implementation summary

### For Technical Details
- **docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md** - Comprehensive technical documentation

## What This Fixes

**Before:**
- academy.biji-biji.com showed default Open edX branding ("Welcome to My Open edX")
- Generic footer and logo
- Different branding from academyv2.mereka.io

**After:**
- academy.biji-biji.com shows Mereka Academy branding
- Same footer and logo as academyv2.mereka.io
- Consistent branding across both domains

## Files Changed

### Modified
- `scripts/shared/multisite_bootstrap.py` - Added MEREKA org and site configs
- `infrastructure/tutor/multisite-sites.yml` - Updated documentation

### New Files
- `scripts/shared/multisite_bootstrap_django.py` - Django ORM implementation
- `scripts/infra/apply-multisite-config.sh` - Automated deployment script
- `docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md` - Technical docs
- `ALTERNATIVE_DOMAIN_FIX_SUMMARY.md` - Implementation summary
- `DEPLOY_BRANDING_FIX.md` - Deployment guide
- `FIX_README.md` - This file

## Testing

The fix has been tested in dry-run mode:

```
✓ Python syntax valid
✓ Shell script syntax valid
✓ Dry-run executes successfully
✓ Scripts have correct permissions
✓ Documentation complete
```

## Deployment Readiness

- [x] Code complete
- [x] Scripts tested (dry-run)
- [x] Documentation complete
- [x] Rollback plan documented
- [ ] Production deployment approved
- [ ] Deployment scheduled

## Next Steps

1. Review all documentation
2. Get deployment approval
3. Schedule deployment window
4. Execute deployment (see DEPLOY_BRANDING_FIX.md)
5. Verify changes
6. Monitor for issues

## Support

If issues occur during deployment:
- See troubleshooting section in DEPLOY_BRANDING_FIX.md
- Check logs: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms`
- Rollback if needed: `kubectl rollout undo deployment/lms -n mereka-lms`

## Success Criteria

The fix is successful when academy.biji-biji.com displays:
- ✓ "Mereka Academy" in header (not "My Open edX")
- ✓ Mereka logo
- ✓ Same footer as academyv2.mereka.io
- ✓ Working navigation and course catalog
