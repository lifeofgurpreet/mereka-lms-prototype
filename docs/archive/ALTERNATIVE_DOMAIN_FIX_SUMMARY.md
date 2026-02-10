# Alternative Domain Branding Fix - Implementation Summary

## Issue
The alternative domain `academy.biji-biji.com` shows default Open edX branding ("Welcome to My Open edX") instead of Mereka Academy branding.

## Root Cause
The multisite bootstrap configuration was missing:
1. Site configuration for the main domain `academyv2.mereka.io`
2. Correct configuration for `academy.biji-biji.com` to use Mereka Academy branding (not separate Biji-Biji branding)

## Solution Implemented

### Files Modified

1. **scripts/shared/multisite_bootstrap.py**
   - Added MEREKA organization
   - Added site configuration for academyv2.mereka.io
   - Changed academy.biji-biji.com to use Mereka Academy branding

2. **scripts/shared/multisite_bootstrap_django.py** (NEW)
   - Django ORM-based version for running inside LMS pods
   - Uses Django models instead of raw SQL
   - Better compatibility with production environment

3. **scripts/infra/apply-multisite-config.sh** (NEW)
   - Automated deployment script
   - Supports dry-run mode
   - Handles kubectl operations safely

4. **infrastructure/tutor/multisite-sites.yml**
   - Updated documentation to match implementation
   - Added missing fields (course_org_filter, homepage_banner_enabled)

5. **docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md** (NEW)
   - Comprehensive documentation
   - Troubleshooting guide
   - Technical details

## Configuration Details

### Both academyv2.mereka.io and academy.biji-biji.com now have:
- `platform_name: "Mereka Academy"`
- `site_name: "Mereka Academy"`
- `THEME_NAME: "mereka"`
- `ENABLE_COMPREHENSIVE_THEMING: true`
- `course_org_filter: ["MEREKA"]`
- `homepage_banner_enabled: false`

### skillourfuture.academy.mereka.io maintains separate branding:
- `platform_name: "Skill Our Future"`
- `site_name: "Skill Our Future"`
- `THEME_NAME: "mereka"` (uses same theme but different configs)
- `course_org_filter: ["SKILLOURFUTURE"]`
- Custom homepage hero banner

## Deployment Steps

### 1. Test in Dry Run Mode (SAFE)
```bash
./scripts/infra/apply-multisite-config.sh --dry-run
```

Expected output shows 3 organizations and 3 sites will be configured.

### 2. Apply to Production
```bash
./scripts/infra/apply-multisite-config.sh --apply
```

This will:
- Create/update MEREKA, BIJIBIJI, SKILLOURFUTURE organizations
- Create/update site configurations for all 3 domains
- Apply proper branding settings

### 3. Restart LMS Pods (Recommended)
```bash
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout status deployment/lms -n mereka-lms
```

### 4. Verify Changes
Test all domains:
- https://academyv2.mereka.io - Should show "Mereka Academy"
- https://academy.biji-biji.com - Should show "Mereka Academy" (same as above)
- https://skillourfuture.academy.mereka.io - Should show "Skill Our Future"

## Success Criteria

- [ ] academy.biji-biji.com homepage shows "Mereka Academy" not "My Open edX"
- [ ] academy.biji-biji.com footer matches academyv2.mereka.io footer
- [ ] academy.biji-biji.com logo is Mereka logo
- [ ] Both domains show identical branding
- [ ] skillourfuture.academy.mereka.io shows separate Skill Our Future branding

## Technical Notes

### Why Django ORM Instead of PyMySQL?
The original `multisite_bootstrap.py` uses PyMySQL for direct database access. However, LMS pods don't have PyMySQL installed by default. The Django ORM version (`multisite_bootstrap_django.py`) uses Django's built-in database layer which is always available in LMS pods.

### Why Both Domains Use Same Branding?
The alternative domain `academy.biji-biji.com` serves as an **alias** for the main Mereka Academy site, not a separate branded experience. This allows Biji-Biji Initiative to have their own domain while maintaining consistent Mereka Academy branding.

### Site Configuration Precedence
Open edX checks Django's `Site` model based on the incoming `Host` header. When a request comes to `academy.biji-biji.com`, Django finds the matching Site record and applies its SiteConfiguration, which now points to Mereka Academy branding.

## Rollback Plan

If issues occur after deployment:

1. **Immediate**: Restart LMS pods to reload configuration
   ```bash
   kubectl rollout restart deployment/lms -n mereka-lms
   ```

2. **Database Rollback**: Use Django admin to modify site configurations
   - Access Django admin at: https://academyv2.mereka.io/admin
   - Navigate to: Sites > Site configurations
   - Edit the problematic site configuration

3. **Full Rollback**: Restore database from backup
   ```bash
   # List available backups
   gsutil ls gs://staging-academy-mereka-io-backup/sql/

   # Restore from specific backup
   # (See docs/operations/BACKUP_RESTORE.md for full procedure)
   ```

## Related Documentation

- **Main Fix Documentation**: docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md
- **Multisite Setup**: docs/operations/MULTISITE.md
- **Deployment Script**: scripts/infra/apply-multisite-config.sh
- **Bootstrap Script (Django)**: scripts/shared/multisite_bootstrap_django.py
- **Bootstrap Script (Direct SQL)**: scripts/shared/multisite_bootstrap.py
- **Configuration File**: infrastructure/tutor/multisite-sites.yml

## Testing Checklist

Before marking as complete:
- [ ] Dry-run completes without errors
- [ ] Apply completes without errors
- [ ] LMS pods restart successfully
- [ ] academyv2.mereka.io shows Mereka branding
- [ ] academy.biji-biji.com shows Mereka branding (not default Open edX)
- [ ] Both domains show identical branding
- [ ] Footer shows correct Mereka links and copyright
- [ ] Logo displays correctly on both domains
- [ ] Login works on both domains
- [ ] Course catalog shows on both domains
- [ ] skillourfuture domain still shows its own branding

## Next Steps (After Deployment)

1. Monitor logs for any errors:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 -f
   ```

2. Test user flows:
   - Login/logout on both domains
   - Course enrollment
   - Dashboard access

3. Update any external documentation that references the branding

4. Consider adding automated tests for multi-domain branding

## Questions & Answers

**Q: Why not use separate Biji-Biji branding for academy.biji-biji.com?**
A: The current requirement is to have both domains show identical Mereka Academy branding. If separate branding is needed in the future, create a new theme directory and update the site configuration.

**Q: Will this affect existing users or courses?**
A: No. This only changes visual branding and site configuration. User accounts, course data, and enrollments are unaffected.

**Q: What if DNS changes are needed?**
A: DNS for academy.biji-biji.com is already configured. The issue was only missing database configuration. See docs/operations/CLOUDFLARE_DNS.md for DNS management.

**Q: Can we test this locally first?**
A: Local testing requires running the full Tutor stack locally. The dry-run mode provides safe preview of changes without affecting production.

## Files Changed Summary

```
Modified:
  scripts/shared/multisite_bootstrap.py
  infrastructure/tutor/multisite-sites.yml

Created:
  scripts/shared/multisite_bootstrap_django.py
  scripts/infra/apply-multisite-config.sh
  docs/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md
  ALTERNATIVE_DOMAIN_FIX_SUMMARY.md (this file)
```

## Approval Checklist

- [ ] Code reviewed
- [ ] Documentation complete
- [ ] Dry-run tested successfully
- [ ] Rollback plan documented
- [ ] Production deployment scheduled
- [ ] Stakeholders notified
