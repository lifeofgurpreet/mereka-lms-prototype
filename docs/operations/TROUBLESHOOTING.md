# Troubleshooting Guide
_Audience: Developers & Agents • Owner: SRE • Last verified: 2025-11-11_

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
- HTTP works but HTTPS (`https://staging.academy.mereka.io` or LB IP on 443) times out
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
curl -Ik https://staging.academy.mereka.io
```

**One-command repair (selectors + HTTPS):**
```bash
./scripts/infra/repair-staging-routing.sh
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
- Missing CSRF trusted origins/cookie domains for custom hostnames (`academy.biji-biji.com`, `skillourfuture.staging.academy.mereka.io`, etc.), or a user profile with corrupt `meta` JSON.

**Quick Fix:**
```bash
# Add trusted origins and cookie domains in rendered configmap
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o yaml \
  | sed -E 's#"CSRF_TRUSTED_ORIGINS": \\[.*\\]#"CSRF_TRUSTED_ORIGINS": ["https://staging.academy.mereka.io","https://studio.staging.academy.mereka.io","https://apps.staging.academy.mereka.io","https://academy.biji-biji.com","https://skillourfuture.staging.academy.mereka.io"]#' \
  | sed 's/"CSRF_COOKIE_DOMAIN": ""/"CSRF_COOKIE_DOMAIN": "staging.academy.mereka.io"/' \
  | sed 's/"SESSION_COOKIE_DOMAIN": ""/"SESSION_COOKIE_DOMAIN": ".staging.academy.mereka.io"/' \
  | kubectl apply -f -
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms

# If a specific user throws JSONDecodeError on login, reset profile.meta and password:
kubectl exec -n mereka-lms deploy/lms -- bash -c "
cd /openedx/edx-platform && ./manage.py lms shell -c \\
\"from django.contrib.auth import get_user_model; U=get_user_model(); u=U.objects.get(username='gurpreet@biji-biji.com'); p=u.profile; p.meta='{}'; p.save(); u.set_password('Cr3ativity'); u.save()\""
```

**Prevention:**
- Keep the trusted origins list in sync with all served hostnames (staging, studio, apps, academy.biji-biji.com, skillourfuture.*).
- Avoid corrupting `profile.meta`; if corruption occurs, set it back to `{}`.

---

### Issue 8: Auth MFE not used (still classic login)

**Symptoms:**
- Login page shows classic LMS form instead of Auth MFE at `/authn`.

**Fix:**
```bash
# Set MFE URLs in rendered configmap
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o jsonpath='{.data.lms\\.env\\.json}' > /tmp/lms.json
kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o jsonpath='{.data.cms\\.env\\.json}' > /tmp/cms.json

# Edit both to include:
#   LOGIN_MICROFRONTEND_URL: https://apps.staging.academy.mereka.io/authn
#   LOGISTRATION_MICROFRONTEND_URL: https://apps.staging.academy.mereka.io/authn
# Ensure CSRF trusted origins include staging/studio/apps/academy.biji-biji.com/skillourfuture.*

# Patch the configmap (example using JSON strings)
LMS=$(python3 - <<'PY'\nimport json; print(json.dumps(open('/tmp/lms.json').read()))\nPY)
CMS=$(python3 - <<'PY'\nimport json; print(json.dumps(open('/tmp/cms.json').read()))\nPY)
kubectl patch cm openedx-config-5t8bdcb64h -n mereka-lms --type=merge -p "{\"data\":{\"lms.env.json\":$LMS,\"cms.env.json\":$CMS}}"

# Restart frontends
kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
```

**Note:** Ensure the MFE image includes `frontend-app-authn` and Caddy/nginx routes `/authn` to the MFE (already true for apps.staging).

---

### Issue 9: Database Connection Errors

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
kubectl exec -n mereka-lms deploy/nginx -- curl -H "Host: staging.academy.mereka.io" http://lms:8000
```

### Check LoadBalancer
```bash
# LoadBalancer status
kubectl get svc caddy -n mereka-lms -o yaml | grep -A 5 "loadBalancer"

# Test external IP directly
curl -k -I https://34.126.186.80 -H "Host: staging.academy.mereka.io"

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
3. If endpoints are empty, run `./tools/fix-service-selectors.sh`
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

Save this as `tools/fix-service-selectors.sh`:

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

- [`docs/ops/DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md) - Full deployment procedures
- [`docs/ACCESS_URLS.md`](../ACCESS_URLS.md) - Service URLs and access info
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

