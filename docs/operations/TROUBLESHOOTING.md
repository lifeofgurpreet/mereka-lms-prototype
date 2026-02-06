# Troubleshooting Guide
_Audience: Developers & Agents • Owner: SRE • Last verified: 2026-02-05_

Quick reference for diagnosing and fixing common Kubernetes service issues. This guide covers the most frequent problems that cause site downtime.

## 🚨 Site Down - Quick Diagnostic Checklist

When the site is inaccessible, run these commands in order:

```bash
# 1. Check if pods are running
kubectl get pods -n mereka-lms

# 2. Check service endpoints (CRITICAL - empty endpoints = no traffic routing)
kubectl get endpoints -n mereka-lms

# 3. Check service selectors match pod labels
kubectl get svc -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.selector}{"\n"}{end}'
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms --show-labels | head -1

# 4. Check LoadBalancer status
kubectl get svc caddy -n mereka-lms

# 5. Test internal connectivity
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms -- curl -I http://lms:8000
```

---

## 🔧 Common Issues & Fixes

### Issue 1: Service Has No Endpoints (`<none>`)

**Symptoms:**
- `kubectl get endpoints` shows `<none>` for a service
- Service exists but can't route traffic
- Pods are running but unreachable

**Root Cause:**
Service selector doesn't match pod labels. This happens when:
- Pods are restarted/recreated with new instance IDs
- Tutor regenerates configs with different instance IDs
- Manual pod deletions/recreations

**Quick Fix:**
```bash
# 1. Get current pod instance ID
POD_INSTANCE=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}')

# 2. Get service selector instance ID
SVC_INSTANCE=$(kubectl get svc lms -n mereka-lms -o jsonpath='{.spec.selector.app\.kubernetes\.io/instance}')

# 3. If they don't match, update the service
if [ "$POD_INSTANCE" != "$SVC_INSTANCE" ]; then
  kubectl get svc lms -n mereka-lms -o yaml > /tmp/lms-svc.yaml
  sed -i.bak "s/$SVC_INSTANCE/$POD_INSTANCE/g" /tmp/lms-svc.yaml
  kubectl apply -f /tmp/lms-svc.yaml
  echo "✓ Fixed LMS service selector"
fi
```

**Bulk Fix Script:**
```bash
# Fix all services at once
for svc in lms cms caddy nginx discovery ecommerce notes xqueue; do
  POD_INSTANCE=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=$svc -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
  if [ -n "$POD_INSTANCE" ]; then
    kubectl get svc $svc -n mereka-lms -o yaml > /tmp/${svc}-svc.yaml
    OLD_INSTANCE=$(grep -o 'openedx-[^"]*' /tmp/${svc}-svc.yaml | head -1)
    if [ "$OLD_INSTANCE" != "$POD_INSTANCE" ] && [ -n "$OLD_INSTANCE" ]; then
      sed -i.bak "s/$OLD_INSTANCE/$POD_INSTANCE/g" /tmp/${svc}-svc.yaml
      kubectl apply -f /tmp/${svc}-svc.yaml && echo "✓ Fixed $svc"
    fi
  fi
done
```

---

### Issue 2: Nginx Upstream Timeout

**Symptoms:**
- Nginx logs show: `upstream timed out` or `upstream prematurely closed connection`
- Nginx can't reach backend services (LMS, CMS, etc.)
- Site returns 502/504 errors

**Root Cause:**
- DNS resolution failing in nginx (`lms:8000` times out)
- Service IP changed but nginx config still uses DNS name

**Quick Fix:**
```bash
# Option 1: Use service ClusterIP directly (more reliable)
SVC_IP=$(kubectl get svc lms -n mereka-lms -o jsonpath='{.spec.clusterIP}')
kubectl get configmap nginx-config-hbdc8f9mfd -n mereka-lms -o yaml > /tmp/nginx-config.yaml
sed -i.bak "s/server lms:8000/server $SVC_IP:8000/g" /tmp/nginx-config.yaml
kubectl apply -f /tmp/nginx-config.yaml
kubectl delete pod -n mereka-lms -l app.kubernetes.io/name=nginx

# Option 2: Restart nginx to refresh DNS cache
kubectl delete pod -n mereka-lms -l app.kubernetes.io/name=nginx
```

---

### Issue 3: LoadBalancer Connection Refused

**Symptoms:**
- External access fails: `Connection refused`
- LoadBalancer IP exists but no traffic reaches pods
- `kubectl get endpoints caddy` shows `<none>`

**Root Cause:**
Caddy service selector mismatch (same as Issue 1, but affects external access)

**Quick Fix:**
```bash
# Fix Caddy service selector
POD_INSTANCE=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=caddy -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}')
kubectl get svc caddy -n mereka-lms -o yaml > /tmp/caddy-svc.yaml
sed -i.bak "s/openedx-[^/]*/$POD_INSTANCE/g" /tmp/caddy-svc.yaml
kubectl apply -f /tmp/caddy-svc.yaml
sleep 3 && kubectl get endpoints caddy -n mereka-lms
```

---

### Issue 4: HTTPS Port Missing on Caddy

**Symptoms:**
- HTTP works but HTTPS (`https://academyv2.mereka.io` or LB IP on 443) times out
- `kubectl get svc caddy -n mereka-lms -o jsonpath='{.spec.ports[*].port}'` shows only `80`

**Root Cause:**
- Caddy Service was created without port 443. The GCP LoadBalancer never opens TLS, so all HTTPS requests fail.

**Quick Fix:**
```bash
# Add port 443 to caddy service (idempotent if 443 is missing)
kubectl patch svc caddy -n mereka-lms --type='json' \
  -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "https", "port": 443, "protocol": "TCP", "targetPort": 443}}]'

# Verify ports now include 80 and 443
kubectl get svc caddy -n mereka-lms -o jsonpath='{.spec.ports[*].port}'

# Wait 5-15 minutes for GCP LB propagation, then test:
curl -Ik https://academyv2.mereka.io
```

**One-command repair (selectors + HTTPS):**
```bash
./scripts/infra/repair-routing.sh
```

---

### Issue 4b: Fake Ingress Certificate

**Symptoms:**
- TLS cert shows `Kubernetes Ingress Controller Fake Certificate`
- Browser warns about invalid certificate on `academyv2.mereka.io`

**Root Cause:**
- DNS points at the wrong LoadBalancer IP, or
- The Ingress/Certificate SAN list does not include the hostname

**Quick Fix:**
```bash
# 1) Validate cert SANs
./scripts/infra/check-cert-sans.sh

# 2) Confirm Ingress hosts + certs include the domain
kubectl get ingress openedx-lms -n mereka-lms
kubectl get certificate openedx-lms-tls -n mereka-lms -o jsonpath='{.spec.dnsNames}'

# 3) Ensure DNS is pointing at the Ingress LoadBalancer IP
kubectl get ingress openedx-lms -n mereka-lms -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
./scripts/infra/cloudflare-sync.sh  # records.json should target the ingress IP

# 4) Verify live certificate (should be Let's Encrypt)
echo | openssl s_client -servername academyv2.mereka.io -connect academyv2.mereka.io:443 2>/dev/null | \
  openssl x509 -noout -subject -issuer
```

**Notes:**
- If the fake cert persists, confirm:
  - The hostname appears on an Ingress in `mereka-lms` (use `./scripts/qa/list-openedx-hostnames.sh`), and
  - The matching `Certificate` includes the hostname in `spec.dnsNames`.
- Production is GitOps-managed; Ingress/Certificate changes must land in:
  - `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/*`
- When enabling new services (credentials/forum), add/update DNS records in `infrastructure/cloudflare/records*.json` and re-run `./scripts/infra/cloudflare-sync.sh`.
- Re-run `./scripts/infra/repair-routing.sh` after any selector drift.

---

### Issue 4c: Studio "Servers Encountered an Error" (MongoDB SRV)

**Symptoms:**
- Studio shows “The Studio servers encountered an error”
- `cms` logs show: `pymongo.errors.ConfigurationError: The "dnspython" module must be installed to use mongodb+srv:// URIs`

**Root Cause:**
- Open edX image is missing `dnspython`, required for MongoDB Atlas SRV URIs

**Fix (Permanent):**
```bash
# 1) Ensure build patches install pymongo SRV extras
rg -n "pymongo\\[srv\\]" infrastructure/tutor/apply-patches.sh

# 2) Re-apply patches and rebuild image
./infrastructure/tutor/apply-patches.sh
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build openedx

# 3) Push + update deployments (GKE)
docker tag tutor_local/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
kubectl set image deployment/cms cms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG -n mereka-lms
kubectl rollout status deployment/cms -n mereka-lms
```

---

### Issue 4d: LMS/CMS MySQL `1045 Access denied` (Trailing Newline In Secret)

**Symptoms:**
- LMS/CMS logs show: `MySQLdb.OperationalError: (1045, "Access denied for user 'openedx'@'10.x.x.x' (using password: YES)")`
- `manage.py lms shell -c ...` fails, even when the site still serves `200` for some pages

**Root Cause:**
- `OPENEDX_MYSQL_PASSWORD` was injected with a trailing newline (`\\n`) from the secret store (Infisical/GCP Secret Manager/ESO).
- The MySQL user password in the database does not include that newline, so auth fails.

**How to Confirm (no secret value printed):**
```bash
kubectl exec -n mereka-lms deploy/lms -- python - <<'PY'
import os
pw = os.environ.get("OPENEDX_MYSQL_PASSWORD", "")
print("len", len(pw))
print("endswith_newline", pw.endswith("\\n"))
print("endswith_cr", pw.endswith("\\r"))
PY
```

**Fix (Permanent):**
- The Open edX K8s settings templates strip trailing CR/LF before assigning the DB password:
  - `deploy/k8s/base/apps/openedx/settings/lms/production.py`
  - `deploy/k8s/base/apps/openedx/settings/cms/production.py`

Apply the overlay and restart LMS/CMS so the updated settings configmaps are mounted:
```bash
kubectl apply -k deploy/k8s/overlays/production
kubectl rollout restart -n mereka-lms deploy/lms deploy/lms-worker deploy/cms deploy/cms-worker
```

**Follow-up (recommended):**
- Normalize the upstream secret values to remove trailing newlines so other services don’t hit the same edge case.
- Use `scripts/infra/infisical-audit-mereka-lms.sh` to detect newline drift without printing values.

### Issue 5: Account Settings/Profile Pages Blank or Stuck

**Symptoms:**
- `/account/settings` or `/u/<user>` loads header/footer only
- Console errors: `Script error for "gettext"`
- 404 for `/static/js/i18n/<lang>/djangojs.js`

**Root Cause (most common now):**
Account/profile pages are still using legacy LMS templates instead of the MFEs.
The MFEs are healthy, but the redirect flags/config are not enabled. Stale
cookies can produce the same symptoms—test in a fresh browser profile first.

**Preferred Fix (redirect to MFEs):**
```bash
kubectl exec -n mereka-lms deploy/lms -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py lms shell -c \
  \"from openedx.core.djangoapps.site_configuration.models import SiteConfiguration; \
from waffle.models import Flag; \
domains=['academyv2.mereka.io','academy.biji-biji.com','skillourfuture.academy.mereka.io']; \
for domain in domains: \
    site = SiteConfiguration.objects.filter(site__domain=domain).first(); \
    values = dict(site.site_values); \
    values['ENABLE_ACCOUNT_MICROFRONTEND'] = True; \
    values['ENABLE_PROFILE_MICROFRONTEND'] = True; \
    site.site_values = values; site.save(); \
for name in ['account.redirect_to_microfrontend','learner_profile.redirect_to_microfrontend']: \
    Flag.objects.update_or_create(name=name, defaults={'everyone': True}); \
\""
```

**Legacy Fix (if you must keep LMS pages):**
`compilejsi18n` was not run for LMS/CMS, so translated JS bundles are missing.

**Quick Fix (in running pods):**
```bash
./scripts/infra/refresh-i18n-static.sh

# Or run manually:
kubectl exec -n mereka-lms deploy/lms -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py lms compilejsi18n --output /openedx/staticfiles/js/i18n"

kubectl exec -n mereka-lms deploy/cms -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py cms compilejsi18n --output /openedx/staticfiles/studio/js/i18n"
```

**Permanent Fix:**
- Ensure the Open edX image build runs `compilejsi18n` (or `collectstatic` pipeline includes it).
- Rebuild and redeploy the image after theme changes.

---

### Issue 6: Studio “New Course” Disabled

**Symptoms:**
- “New Course” opens but “Create” stays disabled
- No console errors
- User is staff/superuser but still can’t create

**Root Cause:**
User lacks a `CourseCreator` record with `state=granted`.

**If the modal still no-ops and console shows 403 AJAX errors:**
- CMS cookies/CSRF may not be scoped to `.academyv2.mereka.io`.
- Ensure `SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` are set in
  `deploy/k8s/base/apps/openedx/settings/cms/production.py`, then rebuild
  and redeploy the Open edX image.

**Fix:**
```bash
kubectl exec -n mereka-lms deploy/cms -- /bin/bash -c \
  "cd /openedx/edx-platform && ./manage.py cms shell -c \
  \"from django.contrib.auth import get_user_model; \
from cms.djangoapps.course_creators.models import CourseCreator; \
u=get_user_model().objects.get(email='gurpreet@biji-biji.com'); \
qs=CourseCreator.objects.filter(user=u); \
(qs.update(state=CourseCreator.GRANTED, all_organizations=True) if qs.exists() \
else CourseCreator.objects.bulk_create([CourseCreator(user=u, state=CourseCreator.GRANTED, all_organizations=True)]));\""
```

---

### Issue 6a: Kind Dev ImagePullBackOff (OpenedX images)

**Symptoms:**
- `lms/cms` pods stuck in `ImagePullBackOff` on `kind-dev`
- Images are private (`asia-southeast1-docker.pkg.dev/...`)

**Root Cause:**
Kind nodes do not have Artifact Registry credentials by default.

**Fix:**
```bash
# One command end-to-end (loads image, applies overlay, verifies health+branding)
./scripts/infra/apply-kind-overlay.sh

# Or, if you only need to load the image into kind nodes (cluster name = dev):
./scripts/infra/kind-load-openedx-image.sh
```

**Notes:**
- Keep the dev tag aligned with production (`deploy/k8s/base/kustomization.yaml`).
- If the tag changes, re-run `./scripts/infra/kind-load-openedx-image.sh` (it infers the tag from the overlay).

---

### Issue 7: No Courses Visible / Modulestore Permission Errors

**Symptoms:**
- `CourseOverview.objects.count()` returns 0
- CMS/LMS errors: `user is not allowed to do action [find] on [openedx.modulestore]`

**Root Cause:**
MongoDB Atlas user only has `readWrite` on `cs_comments_service`, not `openedx`.

**Fix:**
1. Grant the MongoDB user read/write on the `openedx` database in Atlas.
2. Ensure `MONGODB_USERNAME` + `MONGODB_PASSWORD` secrets are correct and synced.
3. Redeploy LMS/CMS to pick up updated credentials.

**Fix (Dev kind):**
```bash
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
kubectl rollout restart deployment/cms -n mereka-lms
```

---

### Issue 4d: Forum Heartbeat 502 (Atlas Allowlist)

**Symptoms:**
- `https://forum.academyv2.mereka.dev/heartbeat` returns 502 (dev)
- `forum` pod logs show MongoDB connection failures

**Most common root causes:**
1. **Dev is accidentally pointing to Atlas SRV.** The forum container generates a `mongoid.yml`
   from env vars; SRV-style values and/or unquoted special characters can cause `Psych::SyntaxError`
   and crashloop.
2. **Atlas allowlist drift.** MongoDB Atlas is on **public IP allowlists**; the VPS egress IP is
   missing from the allowlist.

**Preferred fix (kind dev): use in-cluster MongoDB**
Dev defaults to using the in-cluster `mongodb` service (no auth, no TLS) via the local overlay
patch `deploy/k8s/overlays/local/patches/forum-dev.yaml`.

```bash
kubectl apply -k deploy/k8s/overlays/local --context kind-dev
kubectl rollout restart deployment/forum -n mereka-lms --context kind-dev
curl -I https://forum.academyv2.mereka.dev/heartbeat
```

**Quick Fix:**
```bash
# From VPS (dev) host — IPv4 only (Atlas doesn't accept IPv6)
VPS_IP=$(curl -s -4 https://ifconfig.me || curl -s https://api.ipify.org)

# Add to Atlas allowlist (requires atlas CLI login)
atlas projects list --output json | jq -r '.results[] | [.name,.id] | @tsv'
atlas accessLists create "$VPS_IP" --projectId <atlas-project-id>

# Optional: verify allowlist drift
EGRESS_IPS="$VPS_IP" ./scripts/infra/check-atlas-allowlist.sh
```

**Automation (preferred):**
```bash
./scripts/infra/ensure-atlas-allowlist-vps.sh
./scripts/infra/setup-vps-atlas-allowlist-cron.sh
```

**Verify:**
```bash
curl -I https://forum.academyv2.mereka.dev/heartbeat
kubectl logs -n mereka-lms deploy/forum --tail=100
```

---

### Issue 4c: Credentials Service 500 on `/` (Missing SiteConfiguration)

**Symptoms:**
- `https://credentials.academyv2.mereka.io/` returns 500
- Logs show `Site has no siteconfiguration`

**Root Cause:**
- Django Sites entry exists, but the `SiteConfiguration` row was never created for the credentials service.

**Quick Fix:**
```bash
kubectl exec -n mereka-lms deploy/credentials -- ./manage.py shell -c '
from django.contrib.sites.models import Site
from credentials.apps.core.models import SiteConfiguration
site, _ = Site.objects.get_or_create(id=1)
site.domain = "credentials.academyv2.mereka.io"
site.name = "Mereka Credentials"
site.save()
SiteConfiguration.objects.get_or_create(
  site=site,
  defaults={
    "platform_name": "Mereka Academy",
    "lms_url_root": "https://academyv2.mereka.io",
    "homepage_url": "https://academyv2.mereka.io",
  },
)
'
```

**Verify:**
```bash
curl -I https://credentials.academyv2.mereka.io/
```

---

### Issue 5: Redis Host Drift (Requests Hang)

**Symptoms:**
- Pods healthy, selectors correct, but LMS/Studio requests time out or nginx reports 499.
- Internal curl to `http://lms:8000/` hangs; DB/Redis endpoints are up.
- Rendered configmaps show `redis://@10.x.x.x:6379` instead of the service DNS.

**Root Cause:**
- The rendered Open edX configmap (`openedx-config-*.json`) was baked with an old Redis IP. When Redis moves or the IP is wrong, Django cache/celery calls block, hanging every request.

**Quick Fix:**
```bash
# Patch configmap to use the Redis service DNS
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o yaml \
  | sed 's/10\\.[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+:6379/redis:6379/g' \
  | kubectl apply -f -

# Restart frontends to pick up the fix
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
```

**Prevention:**
- Ensure Tutor/Terraform overrides keep `REDIS_HOST=redis` before regenerating configs.
- After `tutor k8s start` or config regenerations, spot-check `openedx-config-*.json` for `redis:6379`.

---

### Issue 6: MySQL Service Has No Endpoints (Cloud SQL)

**Symptoms:**
- `kubectl get endpoints mysql -n mereka-lms` shows `<none>`
- LMS/CMS hang or timeout on database queries
- Direct connection to Cloud SQL IP works, but service DNS doesn't

**Root Cause:**
- MySQL K8s service has a pod selector, but there's no MySQL pod (using Cloud SQL instead)
- K8s ignores manual Endpoints when a selector is present

**Quick Fix:**
```bash
# 1. Remove the selector from MySQL service
kubectl patch svc mysql -n mereka-lms --type='json' -p='[{"op": "remove", "path": "/spec/selector"}]'

# 2. Create/update endpoint pointing to Cloud SQL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: mysql
  namespace: mereka-lms
subsets:
  - addresses:
      - ip: 10.97.0.2
    ports:
      - port: 3306
EOF

# 3. Verify and restart
kubectl get endpoints mysql -n mereka-lms  # Should show 10.97.0.2:3306
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
```

**Prevention:**
- When using Cloud SQL, ensure MySQL service has no selector
- Add MySQL endpoint to K8s manifests or Terraform

---

### Issue 7: Login Fails (CSRF 403 or 500 on login_session)

**Symptoms:**
- Login POST `/api/user/v1/account/login_session/` returns 403 CSRF (referer check failed) or 500 `json.decoder.JSONDecodeError`.
- Classic LMS login page in use (Auth MFE not enabled).

**Root Cause:**
- Missing CSRF trusted origins/cookie domains for custom hostnames (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`, etc.), or a user profile with corrupt `meta` JSON.

**Quick Fix:**
```bash
# Add trusted origins and cookie domains in rendered configmap
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o yaml \
  | sed -E 's#"CSRF_TRUSTED_ORIGINS": \\[.*\\]#"CSRF_TRUSTED_ORIGINS": ["https://academyv2.mereka.io","https://studio.academyv2.mereka.io","https://apps.academyv2.mereka.io","https://academy.biji-biji.com","https://skillourfuture.academy.mereka.io"]#' \
  | sed 's/"CSRF_COOKIE_DOMAIN": ""/"CSRF_COOKIE_DOMAIN": "academyv2.mereka.io"/' \
  | sed 's/"SESSION_COOKIE_DOMAIN": ""/"SESSION_COOKIE_DOMAIN": ".academyv2.mereka.io"/' \
  | kubectl apply -f -
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms

# If a specific user throws JSONDecodeError on login, reset profile.meta and password:
kubectl exec -n mereka-lms deploy/lms -- bash -c "
cd /openedx/edx-platform && ./manage.py lms shell -c \\
\"from django.contrib.auth import get_user_model; U=get_user_model(); u=U.objects.get(username='gurpreet@biji-biji.com'); p=u.profile; p.meta='{}'; p.save(); u.set_password('Cr3ativity'); u.save()\""
```

**Prevention:**
- Keep the trusted origins list in sync with all served hostnames (academyv2, studio, apps, academy.biji-biji.com, skillourfuture.*).
- Avoid corrupting `profile.meta`; if corruption occurs, set it back to `{}`.

---

### Issue 7b: Studio Create Course fails (`User has no profile`)

**Symptoms:**
- Studio “New Course/Library” action errors or no-ops.
- Logs show `User.profile.RelatedObjectDoesNotExist: User has no profile`.

**Fix (create missing profile):**
```bash
kubectl exec -n mereka-lms deploy/lms -- bash -c "
cd /openedx/edx-platform && ./manage.py lms shell -c \\
\"from django.contrib.auth import get_user_model; from common.djangoapps.student.models import UserProfile; U=get_user_model(); u=U.objects.get(email='gurpreet@biji-biji.com'); UserProfile.objects.get_or_create(user=u, defaults={'name': u.username or u.email}); print('✅ Profile ensured')\""
```

**Prevention:**
- Ensure admin/test users are created via LMS login or `createsuperuser` to auto-create profile rows.

---

### Issue 8: Ecommerce OAuth 500 (edx-oauth2)

**Symptoms**
- Ecommerce login redirects to LMS, then returns 500 at `/complete/edx-oauth2/`.

**Likely Cause**
- LMS OAuth2 application key/secret or redirect URIs don’t match ecommerce settings.

**Fix**
1. Confirm the LMS OAuth2 applications exist at `https://academyv2.mereka.io/admin/oauth2_provider/application/`.
2. Ensure the **backend** client ID matches `ECOMMERCE_BACKEND_OAUTH2_KEY` (default `ecommerce`) and the secret matches `ECOMMERCE_BACKEND_OAUTH2_SECRET`.
3. Ensure the **SSO** client ID matches `ECOMMERCE_OAUTH2_KEY` (default `ecommerce-sso`) and the secret matches `ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET`.
4. Ensure SSO redirect URIs include:
   - `https://ecommerce.academyv2.mereka.io/complete/edx-oauth2/`
   - `https://ecommerce.academyv2.mereka.dev/complete/edx-oauth2/`
   - `http://ecommerce.localhost/complete/edx-oauth2/` (dev)

**Notes**
- `ECOMMERCE_EDX_API_KEY` is used for API auth, not OAuth client ID.

---

### Issue 9: Auth MFE not used (still classic login)

**Symptoms:**
- Login page shows classic LMS form instead of Auth MFE at `/authn`.

**Fix:**
```bash
# Set MFE URLs in rendered configmap
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o jsonpath='{.data.lms\\.env\\.json}' > /tmp/lms.json
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o jsonpath='{.data.cms\\.env\\.json}' > /tmp/cms.json

# Edit both to include:
#   LOGIN_MICROFRONTEND_URL: https://apps.academyv2.mereka.io/authn
#   LOGISTRATION_MICROFRONTEND_URL: https://apps.academyv2.mereka.io/authn
# Ensure CSRF trusted origins include academyv2/studio/apps/academy.biji-biji.com/skillourfuture.*

# Patch the configmap (example using JSON strings)
LMS=$(python3 - <<'PY'\nimport json; print(json.dumps(open('/tmp/lms.json').read()))\nPY)
CMS=$(python3 - <<'PY'\nimport json; print(json.dumps(open('/tmp/cms.json').read()))\nPY)
kubectl patch cm openedx-config-5t8bdcb64h -n mereka-lms --type=merge -p "{\"data\":{\"lms.env.json\":$LMS,\"cms.env.json\":$CMS}}"

# Restart frontends
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
```

**Note:** Ensure the MFE image includes `frontend-app-authn` and Caddy/nginx routes `/authn` to the MFE (already true for apps.academyv2).

---

### Issue 10: Database Connection Errors

**Symptoms:**
- Pods crash with `OperationalError` or `DatabaseError`
- Logs show: `Can't connect to MySQL server` or `MongoDB connection failed`
- Services can't start

**Quick Fix:**
```bash
# Check database connectivity from pod
kubectl exec -n mereka-lms deploy/lms -- python -c "import socket; s = socket.socket(); result = s.connect_ex(('10.97.0.2', 3306)); print('Cloud SQL reachable' if result == 0 else 'Cloud SQL NOT reachable'); s.close()"

# Check database service endpoints
kubectl get endpoints -n mereka-lms | grep -E "mysql|mongodb|redis"

# Verify Tutor config
grep -E "MYSQL_HOST|MONGODB_URI" tutor_env/config.yml
```

---

## 🔍 Diagnostic Commands Reference

### Check Service Health
```bash
# All services and endpoints
kubectl get svc,endpoints -n mereka-lms

# Specific service details
kubectl describe svc <service-name> -n mereka-lms

# Pod labels vs service selectors
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms --show-labels
kubectl get svc lms -n mereka-lms -o jsonpath='{.spec.selector}'
```

### Test Internal Connectivity
```bash
# From within cluster
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms -- curl -I http://lms:8000

# From Caddy pod to backend
kubectl exec -n mereka-lms deploy/caddy -- wget -q -O- --timeout=5 http://nginx:80

# From nginx pod to LMS
kubectl exec -n mereka-lms deploy/nginx -- curl -H "Host: academyv2.mereka.io" http://lms:8000
```

### Check LoadBalancer
```bash
# LoadBalancer status
kubectl get svc caddy -n mereka-lms -o yaml | grep -A 5 "loadBalancer"

# Test external IP directly
curl -k -I https://34.126.186.80 -H "Host: academyv2.mereka.io"

# Check firewall rules
gcloud compute firewall-rules list --filter="allowed.ports:443"
```

### View Recent Logs
```bash
# Caddy (reverse proxy)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50 | grep -i error

# Nginx
kubectl logs -n mereka-lms -l app.kubernetes.io/name=nginx --tail=50 | grep -i "error\|timeout\|502\|504"

# LMS
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 | grep -i "error\|database\|mysql"
```

---

## 🔄 Safe Service Restart Procedures

**When to Restart:**
- After configuration changes (Tutor config, nginx config, etc.)
- To pick up new environment variables
- When pods are stuck/unhealthy

**Safe Restart Order:**
1. **Backend services first** (LMS, CMS, Discovery, Ecommerce)
2. **Then reverse proxy** (Nginx)
3. **Finally edge** (Caddy)

**Quick Restart Commands:**
```bash
# Restart a single service
kubectl rollout restart deployment/<service-name> -n mereka-lms

# Restart all backend services
for svc in lms cms discovery ecommerce notes xqueue; do
  kubectl rollout restart deployment/$svc -n mereka-lms
done

# Restart reverse proxy
kubectl rollout restart deployment/nginx -n mereka-lms

# Restart edge (Caddy)
kubectl rollout restart deployment/caddy -n mereka-lms
```

**After Restarting:**
1. Wait for rollout to complete: `kubectl rollout status deployment/<name> -n mereka-lms`
2. **CRITICAL:** Check endpoints: `kubectl get endpoints -n mereka-lms`
3. If endpoints are empty, run `./scripts/infra/fix-service-selectors.sh`
4. Verify service health: `kubectl get pods -n mereka-lms`

**⚠️ Never restart Caddy first** - It will lose connectivity to backends and cause downtime.

---

## 🎯 Prevention: Why This Happens

**Instance ID Changes:**
- Tutor generates instance IDs when creating Kubernetes resources
- When pods are recreated (updates, restarts, failures), they get new instance IDs
- Services keep old selectors pointing to non-existent pods
- **Solution:** Always check endpoints after pod restarts

**When to Check:**
- After `tutor k8s start` or `tutor k8s restart`
- After manual pod deletions
- After Kubernetes cluster maintenance
- When seeing connection/timeout errors

---

## 📋 Quick Recovery Script

Save this as `scripts/infra/fix-service-selectors.sh`:

```bash
#!/usr/bin/env bash
# Fix service selector mismatches after pod restarts
set -euo pipefail

NAMESPACE=${NAMESPACE:-mereka-lms}
SERVICES="lms cms caddy nginx discovery ecommerce notes xqueue"

for svc in $SERVICES; do
  echo "Checking $svc..."
  POD_INSTANCE=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=$svc -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || echo "")
  
  if [ -z "$POD_INSTANCE" ]; then
    echo "  ⚠️  No pods found for $svc, skipping"
    continue
  fi
  
  SVC_INSTANCE=$(kubectl get svc $svc -n "$NAMESPACE" -o jsonpath='{.spec.selector.app\.kubernetes\.io/instance}' 2>/dev/null || echo "")
  
  if [ "$POD_INSTANCE" != "$SVC_INSTANCE" ]; then
    echo "  🔧 Fixing selector: $SVC_INSTANCE -> $POD_INSTANCE"
    kubectl get svc $svc -n "$NAMESPACE" -o yaml > /tmp/${svc}-svc.yaml
    sed -i.bak "s/$SVC_INSTANCE/$POD_INSTANCE/g" /tmp/${svc}-svc.yaml
    kubectl apply -f /tmp/${svc}-svc.yaml && echo "  ✅ Fixed $svc"
  else
    echo "  ✅ $svc selector matches"
  fi
done

echo ""
echo "Verifying endpoints..."
kubectl get endpoints -n "$NAMESPACE" | grep -E "NAME|$SERVICES"
```

---

## 📚 Related Documentation

- [`docs/operations/DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md) - Full deployment procedures
- [`docs/operations/ACCESS_URLS.md`](ACCESS_URLS.md) - Service URLs and access info
- [`docs/DATABASE_ARCHITECTURE.md`](../DATABASE_ARCHITECTURE.md) - Database connectivity guide

---

## 💡 Pro Tips

1. **Always check endpoints first** - Empty endpoints are the #1 cause of "site down"
2. **Use service IPs in nginx** - More reliable than DNS names
3. **Keep instance IDs in sync** - Services and pods must match
4. **Test from within cluster** - Internal connectivity proves backend works
5. **Check LoadBalancer last** - External issues are usually internal problems

---

_Last updated: 2025-11-11 after resolving service selector mismatch issues that caused site downtime_
