# Analytics Console Access Guide
_Audience: Everyone • Owner: Data/Analytics • Last updated: 2025-11-12_

## 🎯 Quick Access

### Why Port-Forwarding?

Superset runs as a **ClusterIP service** inside Kubernetes, which means it's only accessible from within the cluster. To access it from your local machine, you need to create a temporary tunnel using `kubectl port-forward`. This is a secure way to access internal services without exposing them publicly.

**Alternative:** Once DNS is configured, you can access Superset at `https://analytics.staging.academy.mereka.io` (Caddy ingress is already configured).

### Kubernetes (Staging/Production)

**Step 1: Port-forward Superset service**
```bash
kubectl port-forward -n mereka-lms svc/superset 8088:8088
```

Keep this terminal open while using Superset. The port-forward will stop when you close the terminal or press Ctrl+C.

**Step 2: Open in browser**
- **URL:** http://localhost:8088
- **Username:** `admin`
- **Password:** `admin` (default - change after first login)

**Step 3: Verify services are running**
```bash
kubectl get pods -n mereka-lms | grep -E "superset|clickhouse|ralph"
```

Expected output:
```
clickhouse-xxx             1/1     Running
ralph-xxx                  1/1     Running
superset-xxx               1/1     Running
superset-worker-xxx         1/1     Running
superset-worker-beat-xxx    1/1     Running
```

---

## 📊 What You'll See

### Platform-Wide Analytics

Once data starts collecting (may take a few minutes), you'll see:

- **Total Enrollments** across all courses
- **Completion Rates** by course
- **Certificates Issued** platform-wide
- **Enrollment Trends** over time
- **Course Performance** metrics
- **Learner Engagement** statistics
- **Active Users** over time
- **Course Popularity** rankings

### Course-Specific Analytics

- Enrollment count per course
- Completion rates
- Learner progress tracking
- At-risk learners identification
- Problem-level analytics
- Video engagement metrics
- Discussion participation

---

## 🔐 Credentials & Security

### Default Credentials

**Username:** `admin`  
**Password:** `admin`

⚠️ **Important:** Change the default password after first login!

### Reset Password (Kubernetes)

```bash
# Get Superset pod name
SUPERSET_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=superset -o jsonpath='{.items[0].metadata.name}')

# Reset password
kubectl exec -n mereka-lms $SUPERSET_POD -- \
  superset fab reset-password \
  --username admin \
  --password YOUR_NEW_PASSWORD
```

### Access via LMS (Instructor Dashboard)

1. **Log into LMS:** https://staging.academy.mereka.io
2. **Navigate to any course** you're an instructor for
3. **Click "Instructor"** in the top navigation
4. **Look for "Reports" link** - This is added by Aspects
5. **Click "Reports"** to access course analytics

This provides course-specific analytics without needing direct Superset access.

---

## 🚀 Setup Status

### Current Status (2025-11-12)

✅ **All Aspects services running:**
- ClickHouse (data warehouse) - ✅ Running
- Superset (dashboard) - ✅ Running
- Superset Worker - ✅ Running (fixed database connection)
- Superset Worker Beat - ✅ Running (fixed database connection)
- Ralph (event routing) - ✅ Running

✅ **Database:** Connected to Cloud SQL MySQL (`10.97.0.2`)

✅ **Data Collection:** Active - events are being captured and stored

---

## 🔧 Troubleshooting

### Can't Access Superset

**1. Check if port-forward is running:**
```bash
# Check if port 8088 is in use
lsof -i :8088

# If not, start port-forward:
kubectl port-forward -n mereka-lms svc/superset 8088:8088
```

**2. Check if Superset pod is running:**
```bash
kubectl get pods -n mereka-lms | grep superset
```

**3. Check Superset logs:**
```bash
kubectl logs -n mereka-lms deployment/superset --tail=50
```

**4. Restart Superset if needed:**
```bash
kubectl rollout restart deployment/superset -n mereka-lms
```

### No Data Showing

**Wait a few minutes** - Data collection starts automatically but may take time to populate.

**Generate some activity:**
- Enroll in a course
- Complete some content
- View videos
- Participate in discussions

**Check ClickHouse directly:**
```bash
# Port-forward ClickHouse
kubectl port-forward -n mereka-lms svc/clickhouse 8123:8123

# Query tables (in another terminal)
curl 'http://localhost:8123/?query=SHOW TABLES'
```

### Worker Pods Failing

If `superset-worker` or `superset-worker-beat` are in `CrashLoopBackOff`:

```bash
# Check logs
kubectl logs -n mereka-lms deployment/superset-worker --tail=50

# Verify database connection
kubectl exec -n mereka-lms deployment/superset-worker -- \
  env | grep DATABASE_HOST
```

Should show: `DATABASE_HOST=10.97.0.2` (Cloud SQL IP)

---

## 📈 Data Collection Flow

1. **Events captured** from OpenEdX LMS (enrollments, completions, etc.)
2. **Processed by Ralph** (event routing service)
3. **Stored in ClickHouse** (data warehouse)
4. **Visualized in Superset** (dashboards)

**Timeline:** Data appears within minutes of activity, but dashboards may take longer to populate initially.

---

## 🌐 External Access via Ingress

✅ **Caddy ingress is already configured!** Once DNS is set up, Superset will be accessible at:

**URL:** `https://analytics.staging.academy.mereka.io`

### DNS Setup Required

To enable external access, add a DNS A record pointing `analytics.staging.academy.mereka.io` to your Caddy LoadBalancer IP:

```bash
# Get Caddy LoadBalancer IP
kubectl get svc -n mereka-lms caddy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Then add this IP to your DNS provider for `analytics.staging.academy.mereka.io`.

### Current Status

- ✅ Caddy ingress route configured: `analytics.staging.academy.mereka.io → superset:8088`
- ⏳ DNS record needed: Point `analytics.staging.academy.mereka.io` to Caddy LoadBalancer IP
- ✅ Superset service running and healthy
- ✅ Database connection fixed (using Cloud SQL IP: `10.97.0.2`)

Until DNS is configured, use port-forwarding (see Quick Access above).

---

## 📚 Related Documentation

- **Full Aspects Guide:** [`ASPECTS_K8S_DEPLOYMENT.md`](ASPECTS_K8S_DEPLOYMENT.md)
- **Access URLs:** [`../ACCESS_URLS.md`](../ACCESS_URLS.md)
- **Cost Optimization:** [`../COST_OPTIMIZATION.md`](../COST_OPTIMIZATION.md)

---

## 🎓 Quick Reference

| Task | Command |
|------|---------|
| **Access Superset** | `kubectl port-forward -n mereka-lms svc/superset 8088:8088` |
| **Check Status** | `kubectl get pods -n mereka-lms \| grep -E "superset\|clickhouse"` |
| **View Logs** | `kubectl logs -n mereka-lms deployment/superset --tail=50` |
| **Reset Password** | See "Reset Password" section above |
| **Restart Services** | `kubectl rollout restart deployment/superset -n mereka-lms` |

---

## ✅ Next Steps

1. ✅ **Access Superset** via port-forwarding (see Quick Access above)
2. ✅ **Log in** with default credentials (`admin`/`admin`)
3. ✅ **Change password** for security
4. ✅ **Explore dashboards** (may need to wait for data)
5. ✅ **Access from LMS** via Instructor Dashboard → Reports
6. ✅ **Create custom dashboards** as needed

---

**Last Updated:** 2025-11-13  
**Status:** ✅ All services running and accessible

---

## ✅ Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. Check all Superset pods are running
kubectl get pods -n mereka-lms | grep superset

# 2. Test port-forwarding (in one terminal)
kubectl port-forward -n mereka-lms svc/superset 8088:8088

# 3. Test access (in another terminal)
curl -I http://localhost:8088
# Should return: HTTP/1.1 302 FOUND (redirect to login page)

# 4. Check Caddy ingress configuration
kubectl get configmap -n mereka-lms caddy-config-6m26tcbcmd -o yaml | grep analytics

# 5. Get LoadBalancer IP for DNS setup
kubectl get svc -n mereka-lms caddy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Expected Results:**
- ✅ All Superset pods show `1/1 Running`
- ✅ Port-forward returns HTTP 302 (redirect to login)
- ✅ Caddy config shows `analytics.staging.academy.mereka.io` route
- ✅ LoadBalancer IP is returned (e.g., `34.126.186.80`)


