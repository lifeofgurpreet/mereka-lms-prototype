<!-- @spec: cross-cutting-requirements_spec.md -->
# Incident Response Runbook

_Audience: All Engineers · Owner: Engineering Lead · Last updated: 2026-02-24_

Use this runbook during an active incident. Keep it open alongside the terminal.

**Related docs**: [../../policies/operations/ONCALL_ROTATION.md](../../policies/operations/ONCALL_ROTATION.md) · [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md) · [site-down.md](site-down.md) · [emergency-rollback.md](emergency-rollback.md)

---

## Severity Levels

| Severity | Criteria | Response Time | Examples |
|----------|----------|---------------|---------|
| **P1 – Critical** | LMS fully down or data loss | Immediate / 15 min | Empty endpoints → no traffic, MongoDB Atlas unreachable, cert expired on `academyv2.mereka.io` |
| **P2 – High** | Major feature broken, >10% error rate | 30 min | Studio login broken, enrollment failing, Caddy 502 for one region |
| **P3 – Medium** | Degraded performance, non-critical feature broken | 2 hours | Slow page loads, forum search down (Meilisearch), MFE white screen for subset of users |
| **P4 – Low** | Cosmetic or isolated issue | Next business day | Branding asset 404, analytics events missing, single user report |

---

## Step 1: Declare the Incident

1. Post in `#mereka-incidents` immediately — even before you know the cause.
2. Use the template from [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md#incident-declaration-template).
3. Assign Incident Commander (IC). For P1/P2: Engineering Lead or current on-call primary.

---

## Step 2: 5-Command Diagnostic (Site Down)

Run in order. Stop at the first failure — that's your starting point.

```bash
# 1. Are pods running?
kubectl get pods -n mereka-lms

# 2. CRITICAL: Empty endpoints = no traffic routing
kubectl get endpoints -n mereka-lms

# 3. LoadBalancer / Caddy status
kubectl get svc caddy -n mereka-lms

# 4. Recent events on LMS pods
kubectl describe pods -n mereka-lms -l app.kubernetes.io/name=lms | tail -30

# 5. LMS logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50
```

**Most common P1 cause**: empty endpoints after pod restart (service selector mismatch).
```bash
./scripts/infra/fix-service-selectors.sh
kubectl get endpoints -n mereka-lms   # Verify endpoints now show pod IPs
```

---

## Step 3: Common Incident Patterns

### Site Down — Empty Endpoints

**Symptom**: `kubectl get endpoints -n mereka-lms` shows `<none>` for LMS or Caddy.

**Fix**:
```bash
./scripts/infra/fix-service-selectors.sh
kubectl rollout status deployment/lms -n mereka-lms
```

**If fix-service-selectors.sh doesn't help**: check ArgoCD for drift.
```bash
kubectl get app mereka-lms -n argocd -o jsonpath='{.status.sync.status}'
# If OutOfSync: commit the fix to git, wait for ArgoCD to reconcile (3 min)
```

---

### MongoDB Atlas Connectivity Failure

**Symptom**: LMS returns 500, logs show `pymongo.errors.ServerSelectionTimeoutError` or `ConnectionFailure`.

**Diagnose**:
```bash
# Check Atlas credentials are mounted
kubectl get secret mongodb-atlas-credentials -n mereka-lms
kubectl exec -n mereka-lms deploy/lms -- python -c \
  "import pymongo, os; pymongo.MongoClient(os.environ['MONGODB_URI']).admin.command('ping')"
```

**Common causes**:
- Atlas IP whitelist doesn't include GKE NAT IP — check Atlas Network Access panel
- ExternalSecret not synced — `kubectl get externalsecret -n mereka-lms`
- Wrong password in Infisical — rotate via `gcloud secrets versions add`

**Runbook**: [MONGODB_ATLAS_RUNBOOK.md](MONGODB_ATLAS_RUNBOOK.md)

**Postmortem guidance**: [../../status/incidents/README.md](../../status/incidents/README.md)

---

### TLS Certificate Expiry

**Symptom**: Browser shows cert error, `curl -svI https://academyv2.mereka.io` shows expired cert.

**Diagnose**:
```bash
kubectl get certificate -n mereka-lms
kubectl describe certificate lms-tls -n mereka-lms
kubectl get certificaterequest -n mereka-lms | tail -5
```

**Fix** (cert-manager managed):
```bash
# Force renewal
kubectl delete certificaterequest -n mereka-lms -l cert-manager.io/certificate-name=lms-tls
# cert-manager will re-issue within ~2 min; monitor:
kubectl get events -n mereka-lms --field-selector reason=Issued -w
```

**Prevention**: Alert `CertificateExpiringSoon` should fire 14 days before expiry (check Alertmanager).

---

### OOM During Image Build

**Symptom**: `tutor images build openedx` fails with OOM or webpack heap error.

**Symptom strings**: `FATAL ERROR: Ineffective mark-compacts near heap limit`, `Killed`.

**Fix**:
```bash
# Ensure Docker has ≥12 GB RAM and 2-4 GB swap configured in Docker Desktop
# Build with explicit pip backend (avoids uv pip isolation issues)
tutor images build openedx -a PIP_COMMAND=pip
# If webpack OOM specifically:
# Verify NODE_OPTIONS=--max-old-space-size=6144 patch is in apply-patches.sh output
./scripts/infra/verify-tutor-config.sh
```

**Runbook**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

### CrashLoopBackOff on LMS or Workers

**Symptom**: `kubectl get pods -n mereka-lms` shows `CrashLoopBackOff`.

**Diagnose**:
```bash
# Get last termination reason
kubectl describe pod -n mereka-lms <pod-name> | grep -A5 "Last State"
# Previous container logs
kubectl logs -n mereka-lms <pod-name> --previous
```

**Common causes**:
- Missing env var (ExternalSecret not synced)
- Bad Django settings (syntax error in production-prod.py overlay)
- ConfigMap not wired to the crashing deployment

---

## Step 4: Escalation Path

```
Primary on-call
  → (no response in 15 min for P1) → Secondary on-call
  → (no response in 15 min) → Engineering Lead
  → (data loss or security breach) → CTO + Legal
```

Post updates every **15 min for P1**, **30 min for P2** in `#mereka-incidents`.

---

## Step 5: Resolution Checklist

Before declaring the incident resolved:

- [ ] All services show healthy endpoints: `kubectl get endpoints -n mereka-lms`
- [ ] LMS home page returns HTTP 200: `curl -o /dev/null -sw '%{http_code}' https://academyv2.mereka.io`
- [ ] No error rate spike in Prometheus (check `http_requests_total{status=~"5.."}`): https://prometheus.mereka.dev
- [ ] Root cause identified (not just "restarted pods")
- [ ] Post resolution message in `#mereka-incidents` using template in [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md)
- [ ] If P1 or P2: postmortem scheduled within 5 business days

---

## Step 6: Post-Incident

| Severity | Postmortem Required? | Deadline |
|----------|---------------------|----------|
| P1 | Yes | 5 business days |
| P2 | Yes | 5 business days |
| P3 | Optional (if instructive) | 1 week |
| P4 | No | — |

**Postmortem template**: [../../status/incidents/README.md](../../status/incidents/README.md) → full template in [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md).

File as: `docs/status/incidents/YYYY-MM-DD-<slug>.md`

---

## Quick Reference

| Resource | URL / Command |
|----------|--------------|
| Prometheus | https://prometheus.mereka.dev |
| Alertmanager | https://alertmanager.mereka.dev |
| Grafana (if configured) | https://grafana.mereka.dev |
| ArgoCD | `kubectl get app -n argocd` |
| Incident Slack channel | `#mereka-incidents` |
| On-call schedule | `#mereka-operations` (pinned) |
| Fix selectors | `./scripts/infra/fix-service-selectors.sh` |
| Verify Tutor config | `./scripts/infra/verify-tutor-config.sh` |
| Public health check | `./scripts/qa/public-health-check.sh prod` |
