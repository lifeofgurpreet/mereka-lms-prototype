# cm9c Seeder Dry-Run Evidence — 2026-04-24

Bead: mereka-lms-cm9c  
Branch: worktree-agent-a1f8a874  
Source file: `infrastructure/tutor/multisite-sites.yml`

## Collision check output

```
Host ownership check: OK (no shared hosts detected)

validate_site_host_ownership: OK — no blocking collisions
```

Allowlist active:
```
['apps.academyv2.mereka.dev', 'staging.apps.academyv2.mereka.io',
 'staging.studio.academyv2.mereka.io', 'studio.academyv2.mereka.dev']
```

## Dry-run row preview

```
============================================================
DRY RUN MODE - No changes will be made
============================================================

Organizations to create/update:
  - MEREKA: Mereka Academy
  - BIJIBIJI: Biji-Biji Academy
  - SKILLOURFUTURE: Skill Our Future

Sites to create/update:
  - academyv2.mereka.io: Mereka Academy
    Organizations: MEREKA
    Platform name: Mereka Academy
    LMS_ROOT_URL:  https://academyv2.mereka.io
    CMS_ROOT_URL:  https://studio.academyv2.mereka.io
    MFE_BASE_URL:  https://apps.academyv2.mereka.io

  - academy.biji-biji.com: Biji-Biji Academy
    Organizations: BIJIBIJI
    Platform name: Biji-Biji Academy
    LMS_ROOT_URL:  https://academy.biji-biji.com
    CMS_ROOT_URL:  https://studio.academy.biji-biji.com
    MFE_BASE_URL:  https://apps.academy.biji-biji.com

  - skillourfuture.academy.mereka.io: Skill Our Future
    Organizations: SKILLOURFUTURE
    Platform name: Skill Our Future
    LMS_ROOT_URL:  https://skillourfuture.academy.mereka.io
    CMS_ROOT_URL:  https://studio.skillourfuture.academyv2.mereka.io
    MFE_BASE_URL:  https://apps.skillourfuture.academyv2.mereka.io

  - skillourfuture.academyv2.mereka.io: Skill Our Future (studio bridge)
    Organizations: SKILLOURFUTURE
    Platform name: Skill Our Future
    LMS_ROOT_URL:  https://skillourfuture.academyv2.mereka.io
    CANONICAL_LMS_ROOT_URL: https://skillourfuture.academy.mereka.io
```

## Why `apply --apply` will now succeed

Prior attempt would have failed with:

```
LMS_ROOT_URL host 'skillourfuture.academy.mereka.io' is shared by tenants
['skillourfuture.academy.mereka.io', 'skillourfuture.academyv2.mereka.io']
(must be unique or allowlisted)
```

Fix: bridge row's `LMS_ROOT_URL` is now the bridge domain itself
(`https://skillourfuture.academyv2.mereka.io`, unique). The new
`CANONICAL_LMS_ROOT_URL` key carries the real tenant LMS root. The
middleware reads this key preferentially (see `_lms_root_url_for_host`).
No allowlisting needed.

## Expected DB outcome after `--apply`

- `Site.objects.filter(domain="skillourfuture.academyv2.mereka.io").count()` → 1 (was 0)
- `SiteConfiguration` for that site has `LMS_ROOT_URL = "https://skillourfuture.academyv2.mereka.io"` and `CANONICAL_LMS_ROOT_URL = "https://skillourfuture.academy.mereka.io"`
- Middleware resolves `studio.skillourfuture.academyv2.mereka.io` → candidate `skillourfuture.academyv2.mereka.io` → Site found → reads `CANONICAL_LMS_ROOT_URL` → returns `"https://skillourfuture.academy.mereka.io"` → signin redirect rewritten correctly

## Test output (6 passed)

```
test_candidate_site_domains_sof_studio_cross_domain PASSED
test_edx_oauth2_redirect_uses_tenant_lms_host PASSED
test_lms_root_url_for_host_reads_canonical_key PASSED   ← new: proves CANONICAL key path
test_non_matching_redirect_is_unchanged PASSED
test_signin_redirect_uses_tenant_lms_host PASSED
test_sof_cross_domain_studio_signin_redirect PASSED     ← regression guard for bead cm9c
```
