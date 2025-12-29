# Production/Staging Environment Status
**Last Updated:** 2025-11-25
**Environment:** Staging (staging.academy.mereka.io)
**Cluster:** mereka-lms (GKE Autopilot, asia-southeast1)

---

## ✅ Current Status: ALL SERVICES OPERATIONAL

| Service | URL | Status |
|---------|-----|--------|
| LMS | https://staging.academy.mereka.io | ✅ 200 |
| Studio | https://studio.staging.academy.mereka.io | ✅ 200 |
| MFE | https://apps.staging.academy.mereka.io | ✅ 200 |
| Biji-Biji | https://academy.biji-biji.com | ✅ 200 |

---

## ✅ Issues Fixed

### 1. MySQL Service Pointing to Nowhere (2025-11-25)
**Problem:** MySQL K8s service had a pod selector but no MySQL pod exists (using Cloud SQL)
**Fix:** Removed selector from MySQL service, created manual Endpoints pointing to Cloud SQL private IP (10.97.0.2)
**Commands:**
```bash
kubectl patch svc mysql -n mereka-lms --type='json' -p='[{"op": "remove", "path": "/spec/selector"}]'
kubectl apply -f - <<EOF
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
```

### 2. MFE Service Selector Mismatch (2025-11-25)
**Problem:** MFE service selector pointed to old instance ID
**Fix:** Updated selector to match current pod instance ID

### 3. Service Selector Mismatches (2025-11-24)
**Problem:** Caddy, LMS, and CMS services had no endpoints - site was completely down
**Fix:** Ran `./scripts/infra/fix-service-selectors.sh` to update selectors from old instance ID to current
**Result:** ✅ All service endpoints now populated

**Details:**
```
caddy   10.24.0.220:80
cms     10.24.0.225:8000
lms     10.24.0.222:8000
```

### 2. Missing HTTPS Port
**Problem:** LoadBalancer only exposed port 80, not 443
**Fix:** Added HTTPS port to caddy service
**Result:** ✅ Service now exposes both 80:31715/TCP and 443:31990/TCP

**Command Used:**
```bash
kubectl patch svc caddy -n mereka-lms --type='json' \
  -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "https", "port": 443, "protocol": "TCP", "targetPort": 443}}]'
```

---

## 🔄 Pending (Propagation in Progress)

### HTTPS Access via Domain
**Status:** ⏳ Waiting for GCP Load Balancer update (Autopilot clusters may take 5-15 minutes)

**Current State:**
- ✅ HTTP works on IP: `http://34.126.186.80` → Returns 308 redirect to HTTPS
- ✅ Caddy is listening on ports 80 and 443 inside pod
- ⏳ HTTPS on IP: `https://34.126.186.80` → Timing out (load balancer updating)
- ⏳ HTTPS on domain: `https://staging.academy.mereka.io` → Timing out (load balancer updating)

**DNS:**
```
staging.academy.mereka.io → 34.126.186.80 (correct)
```

**Next Steps:**
1. Wait 10-15 minutes for GCP Load Balancer to propagate port 443 configuration
2. Test again: `curl -I https://staging.academy.mereka.io`
3. If still failing after 15 min, check GCP Console → Network Services → Load Balancing for health check status

---

## 📊 Service Health

**All Pods Running:**
```
NAME                             READY   STATUS    RESTARTS   AGE
caddy-64fc6b59bd-b4j6d           1/1     Running   0          10d
cms-859c4598df-t5b5c             1/1     Running   0          3d2h
cms-worker-8869856-9qtvg         1/1     Running   16         3d2h
lms-6988dcc698-db4mm             1/1     Running   0          3d2h
lms-worker-55d9fb957f-8vfjq      1/1     Running   16         3d2h
mfe-668949c97d-r5r6c             1/1     Running   0          3d2h
mongodb-f57676dfb-mrl9d          1/1     Running   0          12d
nginx-7bc74554bd-5qrd6           1/1     Running   0          13d
redis-69b9dcb8d8-lsb5x           1/1     Running   0          3d2h
smtp-dd67d999c-rjnsd             1/1     Running   0          3d2h
elasticsearch-54b9b468c6-nm6cj   1/1     Running   0          14d
```

**Service Endpoints:**
```
caddy     10.24.0.220:80         ✅
cms       10.24.0.225:8000       ✅
lms       10.24.0.222:8000       ✅
mfe       <none>                 ⚠️ (may be normal if not using ClusterIP)
```

---

## 🔧 Manual Verification Steps

**For PM Review (once HTTPS propagates):**

1. **LMS:** https://staging.academy.mereka.io
2. **Studio:** https://studio.staging.academy.mereka.io
3. **MFE Login:** https://apps.staging.academy.mereka.io/authn/login
4. **Admin Panel:** https://staging.academy.mereka.io/admin

**Test After ~15 Minutes:**
```bash
# Quick test
curl -I https://staging.academy.mereka.io

# Should return:
# HTTP/2 200
# server: Caddy
```

---

## 📝 Notes

- **Cluster Type:** GKE Autopilot (no direct node access, managed networking)
- **Load Balancer:** GCP automatically manages L4 LoadBalancer for Kubernetes services
- **SSL/TLS:** Caddy handles automatic HTTPS with Let's Encrypt
- **Firewall:** Autopilot handles firewall rules automatically (manual firewall rule created but may not apply to Autopilot)

---

## 🚨 If HTTPS Still Doesn't Work After 15 Minutes

Check these:

1. **GCP Load Balancer Health Checks:**
   ```bash
   gcloud compute backend-services list
   gcloud compute health-checks list
   ```

2. **Caddy Logs:**
   ```bash
   kubectl logs -n mereka-lms caddy-64fc6b59bd-b4j6d --tail=100
   ```

3. **Service Configuration:**
   ```bash
   kubectl describe svc caddy -n mereka-lms
   ```

4. **Try Port Forward:**
   ```bash
   kubectl port-forward -n mereka-lms svc/caddy 8443:443
   # Then test: curl -Ik https://localhost:8443
   ```
