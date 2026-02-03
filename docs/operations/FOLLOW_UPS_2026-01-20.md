# Mereka LMS Follow-ups (2026-01-20)

This file captures what was verified today and what still needs to happen so you can resume later without re-tracing steps.

## Snapshot (Verified)

- LMS/CMS/MFE pods are Running; ingress hosts for `staging`, `studio`, `apps` are OK.
- Multi-site data exists in DB:
  - Organizations: MEREKA, BIJIBIJI, SKILLOURFUTURE (active).
  - Sites: `academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`.
  - Each site has `course_org_filter` set and theme `mereka`.
- Cookies and CSRF:
  - `SESSION_COOKIE_DOMAIN=.academyv2.mereka.io`
  - `CSRF_COOKIE_DOMAIN=.academyv2.mereka.io`
  - `CSRF_TRUSTED_ORIGINS` includes staging + studio + apps + academy + skillourfuture + auth0.
- OIDC endpoints are live:
  - `/auth/login/oidc/` returns 302 for all three LMS hosts.
  - Authentik OIDC issuer is `https://auth0.mereka.io/application/o/mereka-lms/`.
- MFE config returns JSON; `OIDC` field is `null` (MFE uses LMS login URL).

## Changes Applied Today (Cluster Only)

These were done directly on the cluster and are NOT yet committed into repo sources:

1) Ingress `openedx-lms` updated to include hosts:
   - `academy.biji-biji.com`
   - `skillourfuture.academy.mereka.io`
   TLS cert re-issued successfully with both SANs.

2) LMS settings configmap `openedx-settings-lms-patched` updated:
   - Added the two microsite hosts to `SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS`.
   - Added `academy` + `skillourfuture` to `LOGIN_REDIRECT_WHITELIST`, `CORS_ORIGIN_WHITELIST`, and `CSRF_TRUSTED_ORIGINS`.
   - Restarted `lms` and `lms-worker`.

3) OIDC provider config duplicated per site:
   - Created `OAuth2ProviderConfig` entries for `academy.biji-biji.com` and `skillourfuture.academy.mereka.io`.
   - There are still two existing entries for `academyv2.mereka.io` (duplicate).

## What Still Needs To Happen (Next Steps)

### A) Persist the Cluster Changes in Git (High Priority)

1) Update the Argo/Tutor source manifests so the ingress host/TLS changes don’t get reverted.
   - Find the `openedx-lms` ingress in repo and add:
     - `academy.biji-biji.com`
     - `skillourfuture.academy.mereka.io`
   - Ensure TLS hosts include both.

2) Backport the LMS auth whitelist changes into the repo’s settings patch (source of truth).
   - Add the two hosts to:
     - `SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS`
     - `LOGIN_REDIRECT_WHITELIST`
     - `CORS_ORIGIN_WHITELIST`
     - `CSRF_TRUSTED_ORIGINS`
   - Then re-apply via the normal patch flow.

3) Make OIDC provider config creation repeatable.
   - Add to `scripts/shared/multisite_bootstrap.py` or a new script:
     - Create one `OAuth2ProviderConfig` per site.
   - Clean up duplicate entries for `academyv2.mereka.io`.

### B) Verify External Access (High Priority)

4) From a clean external network (not inside the cluster), verify:
   - `https://academy.biji-biji.com`
   - `https://skillourfuture.academy.mereka.io`
   Note: Cloudflare is in front of `academy.biji-biji.com`. Confirm DNS/proxy mode and SSL mode (Full/Strict) are correct.

5) Verify full OIDC login for each LMS host:
   - Start at `/auth/login/oidc/`
   - Complete Authentik flow
   - Confirm session is created and `api/user/v1/me` returns a logged-in user.

6) Verify Studio SSO still works end-to-end:
   - `/login/` -> `/login/edx-oauth2/` -> LMS OAuth2 -> Authentik -> Studio home.

### C) Data/Content Readiness (Medium Priority)

7) Course overviews show `0` across all orgs.
   - Run `python manage.py lms reindex_courses` on staging.
   - Re-check `CourseOverview` counts per org.

### D) Optional Improvements

8) Decide if MFEs should support native OIDC.
   - `MFE config` shows `OIDC: null`.
   - If needed, configure MFE OIDC settings to point directly at Authentik.

9) Add a `/health` endpoint if you want a simple uptime check.
   - Currently returns `404`.

10) Confirm DB architecture intent.
   - Cluster currently has a `mysql` pod (not Cloud SQL).
   - Align docs and deployment with the intended architecture.

## Quick Commands (When You Resume)

```bash
# Check ingress hosts
kubectl get ingress openedx-lms -n mereka-lms -o jsonpath='{.spec.rules[*].host}'; echo

# Check cert status
kubectl get certificate -n mereka-lms

# Verify OIDC redirect for each host (inside cluster)
kubectl exec -n mereka-lms deploy/lms -- sh -c \
  'for host in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do \
     echo "\n$host"; \
     curl -sS -I -H "Host: $host" http://caddy:80/auth/login/oidc/ | sed -n "1,6p"; \
   done'

# Check OAuth2 provider config per site
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  'from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig; \
   [print(f"{pc.id} {pc.site.domain} {pc.slug} {pc.backend_name} {pc.enabled}") for pc in OAuth2ProviderConfig.objects.all()]'
```
