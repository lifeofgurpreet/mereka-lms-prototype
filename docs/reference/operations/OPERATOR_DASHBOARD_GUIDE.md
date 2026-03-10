# Operator Dashboard Guide — Mereka Academy

_Audience: Platform Engineers • Owner: Engineering Lead • Last verified: 2026-03-06 • Status: canonical_
_Related: [site-down.md](../../ops/runbooks/site-down.md) · [ONCALL_OBSERVABILITY_PLAYBOOK.md](../../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md) · [INCIDENT_RESPONSE.md](../../ops/runbooks/INCIDENT_RESPONSE.md)_

---

## Purpose

This guide is the single starting point for an operator who wants to know:

1. What dashboards and tools exist — and where to find them.
2. Which tool to use for which job.
3. How to escalate if that tool surfaces a problem.

It does **not** replace individual runbooks. It points you to them.

---

## 1. Dashboard Inventory

### 1.1 Grafana Dashboards

Primary observability UI. Access at **https://grafana.mereka.io** (prod) or **https://grafana.mereka.dev** (dev/VPS).

| Dashboard Name | UID | URL path | Purpose |
|---|---|---|---|
| Mereka LMS — Public Endpoints | `bbi-app-mereka-lms` | `/d/bbi-app-mereka-lms` | LMS + Studio + MFE HTTP availability, SLO burn rate, SSL expiry |
| Mereka LMS — Operations Signals | `bbi-ops-mereka-lms` | `/d/bbi-ops-mereka-lms` | MySQL connection saturation, Redis evictions, PVC usage |
| Mereka LMS — GKE | `bbi-gke-mereka-lms` | `/d/bbi-gke-mereka-lms` | Pod CPU/memory by workload, restart counts, node pressure |
| Mereka LMS — Auth | `bbi-auth-mereka-lms` | `/d/bbi-auth-mereka-lms` | Auth failure rates per service (LMS, credentials, forum) |
| ORA2 Grading | (json in repo) | `deploy/k8s/base/monitoring/grafana-dashboard-ora2.json` | ORA2 submission/grading latency and errors |

**Contract**: The dashboard panel inventory is governed by `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`.
**Audit**: `./scripts/qa/audit-grafana-dashboard.sh --strict-required`

Dashboard access requires Grafana login (Authentik SSO). If a panel shows `No data`, check:
1. ServiceMonitor labels match in `deploy/k8s/base/monitoring/servicemonitor-*.yaml`.
2. Prometheus can reach the `/metrics` endpoint of the service.
3. The service has `django-prometheus` (LMS/CMS) or `prometheus-fastapi-instrumentator` (Purchase Gateway) wired in.

---

### 1.2 GCP Cloud Monitoring (Uptime + Alerts)

Project: `bbi-k8`
Access: **console.cloud.google.com → Monitoring** (filter by namespace `mereka-lms`).

| Resource type | File in repo | Description |
|---|---|---|
| Uptime check | `infrastructure/monitoring/uptime/prod-*.json` | HTTPS probes for `academyv2.mereka.io`, microsites, and APIs |
| Dashboard | `infrastructure/monitoring/dashboards/public-endpoints.json` | Uptime SLO view |
| Dashboard | `infrastructure/monitoring/dashboards/operations-signals.json` | Storage, DB, Velero signals |

**Alert policies** managed in `infrastructure/monitoring/alerts/`:

| Alert | Severity | Trigger |
|---|---|---|
| `lb-5xx-ratio.json` | ERROR | Ingress 5xx spike |
| `log-5xx-spike.json` | ERROR | App-level 5xx from logs |
| `https-cert-expiry.json` | ERROR | SSL cert expiry < threshold |
| `log-auth-failures.json` | WARNING | Auth failure spikes |
| `log-stateful-storage-errors.json` | ERROR | ENOSPC / read-only filesystem |
| `log-mysql-connection-errors.json` | WARNING | MySQL connection failures |
| `log-redis-connection-errors.json` | WARNING | Redis connection failures |
| `log-velero-backup-verification-failures.json` | ERROR | Velero backup verification failure |
| `log-velero-restore-test-failures.json` | ERROR | Velero restore drill failure |
| `velero-backup-verification-stale.json` | ERROR | No backup success in 30 h |
| `velero-restore-test-stale.json` | ERROR | No restore success in 45 d |
| `pod-restarts.json` | WARNING | Pod restart count threshold |
| `pvc-utilization-high.json` | WARNING | PVC usage > threshold |
| `mysql-saturation-high.json` | WARNING | MySQL thread saturation |

Full matrix: [ALERT_SEVERITY_MATRIX.md](ALERT_SEVERITY_MATRIX.md)

---

### 1.3 Prometheus / Alertmanager (In-cluster)

PrometheusRules are deployed as K8s resources under `deploy/k8s/base/monitoring/prometheusrule-*.yaml`.

| PrometheusRule file | Key alerts |
|---|---|
| `prometheusrule-lms.yaml` | `LMSPodDown`, `LMSPodRestarting`, `LMSPodMemoryHigh`, `OpenEdxCriticalDeploymentUnavailable`, `OpenEdxCrashLoopingContainers`, `OpenEdxPodsPendingTooLong`, `OpenEdxSyntheticOrBackupJobFailures` |
| `prometheusrule-slo.yaml` | SLO burn rate alerts for Tier 1/2/3 services |
| `prometheusrule-auth.yaml` | Auth failure rate alerts |
| `prometheusrule-caddy.yaml` | Caddy 5xx / latency |
| `prometheusrule-externalsecrets.yaml` | ExternalSecret sync failures |
| `prometheusrule-velero.yaml` | Velero backup/restore alerts |
| `prometheusrule-enterprise.yaml` | Enterprise service health |
| `prometheusrule-tenant-isolation.yaml` | Tenant isolation cronjob |
| `prometheusrule-services.yaml` | Discovery, ecommerce, notes, xqueue |

Verify rules are loaded by Prometheus:
```bash
OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT \
  ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

---

### 1.4 MongoDB Atlas Dashboard

MongoDB Atlas is monitored externally at **https://cloud.mongodb.com/** (cluster: `cluster-mereka-lms.2pjex4s.mongodb.net`).

In-cluster: TCP probe by blackbox exporter → metric `probe_success{job="mongodb-atlas"}`.
Alert: `MongoDBAtlasDown` (severity: critical) fires after 2 min of failed probes.

---

### 1.5 Open edX Django Admin Panel

The standard Open edX admin panel is available at:

| Environment | URL |
|---|---|
| Production | https://academyv2.mereka.io/admin |
| Dev (kind) | https://academyv2.mereka.dev/admin |
| Local | http://localhost/admin |

Access: requires `is_staff=True` or `is_superuser=True` on the LMS user record. See [AUTH_AND_PERMISSIONS.md](AUTH_AND_PERMISSIONS.md) for granting access.

Common operator tasks via Django admin:
- Create/deactivate user accounts
- Enroll or unenroll users from courses
- Reset learner progress (with care — irreversible)
- Manage site configurations (`/admin/sites/site/`)
- View and purge OAuth2 tokens (`/admin/oauth2_provider/`)

---

### 1.6 Admin Console MFE (RBAC + Org Admin)

URL: **https://apps.academyv2.mereka.io/admin-console/**

The `frontend-app-admin-console` MFE replaces Django admin for common RBAC operations:
- Assign/revoke organisation roles (admin, staff, instructor, data researcher)
- Manage content library teams
- View recent permission change audit log

Access: `is_staff=True` OR assigned `organisation_admin` role.
Setup guide: [ADMIN_CONSOLE_SETUP.md](ADMIN_CONSOLE_SETUP.md)

---

### 1.7 Aspects Analytics (Superset) — NOT YET DEPLOYED

Manifests exist at `deploy/k8s/base/plugins/aspects/` but are **not wired into the active kustomization graph**.

| What | Status |
|---|---|
| ClickHouse | Manifests exist, not deployed |
| Superset | Manifests exist, not deployed |
| Secrets (Infisical) | Not provisioned |
| ESO ExternalSecret | Not created |

Target URL when deployed: `https://analytics.academyv2.mereka.io` (prod) / `https://analytics.academyv2.mereka.dev` (dev).
Deployment tracked: T148.
Setup guide (when deployed): [ASPECTS_ANALYTICS_SETUP.md](ASPECTS_ANALYTICS_SETUP.md)

---

## 2. Diagnostic Scripts Reference

Operators use these scripts to confirm platform health without relying on UI dashboards alone.

### 2.1 Health & Observability Checks

| Script | Purpose | Auth required |
|---|---|---|
| `./scripts/qa/public-health-check.sh prod` | HTTP + cert checks for all prod public endpoints | No |
| `CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod` | Same, plus SSL cert expiry check | No |
| `./scripts/qa/audit-observability.sh --mode local` | Monitoring config integrity (repo) | No |
| `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict` | Runtime-first observability evidence gate (compliance + runtime verifier + index) | kubectl + gcloud |
| `./scripts/qa/audit-grafana-dashboard.sh --strict-required` | Grafana panel/query coverage contract | No |
| `./scripts/qa/audit-velero-alert-pipeline.sh` | Velero alert freshness + route sanity | kubectl |
| `./scripts/qa/verify-alert-routing.sh` | Alertmanager routing policies and channels | kubectl |
| `./scripts/qa/run-operations-gates.sh --env both` | Consolidated: auth + multisite + observability + Velero | kubectl |
| `./scripts/qa/verify-slo-dashboards.sh` | SLO dashboard panel contract | kubectl |
| `./scripts/qa/verify-slo-definitions.sh` | SLO PromQL + thresholds in PrometheusRules | No |
| `./scripts/qa/verify-error-budget.sh` | Current error budget consumption per tier | kubectl |

### 2.2 K8s Cluster State

| Script | Purpose | Auth required |
|---|---|---|
| `./scripts/infra/check-cluster-status.sh` | Node + pod summary for `mereka-lms` namespace | kubectl |
| `./scripts/infra/fix-service-selectors.sh` | Repair service selector mismatches (most common P1 fix) | kubectl |
| `./scripts/infra/verify-deployment.sh` | Rolling deploy status — all workloads ready | kubectl |
| `./scripts/infra/verify-k8s-overrides.sh` | Kustomize overlay diff vs base | No |
| `./scripts/qa/verify-k8s-live-cluster.sh` | Live endpoint + secret presence spot-checks | kubectl |
| `./scripts/qa/verify-service-endpoints.sh` | All services have non-empty endpoints | kubectl |

### 2.3 Secrets & ExternalSecrets

| Script | Purpose |
|---|---|
| `./scripts/infra/infisical-validate-mereka-lms.sh` | All required secrets present in Infisical |
| `./scripts/qa/verify-secrets-live-cluster.sh` | ExternalSecret sync status in cluster |
| `./scripts/qa/verify-k8s-externalsecrets.sh` | ESO ExternalSecret objects and last-sync |
| `./scripts/qa/verify-secrets-management.sh` | Secret naming convention and inventory |

### 2.4 Auth / SSO

| Script | Purpose |
|---|---|
| `./scripts/qa/verify-studio-sso-flow.sh` | Studio → LMS → Authentik → Studio OAuth roundtrip |
| `./scripts/qa/verify-auth-hardening.sh` | Auth hardening surface checks |
| `./scripts/qa/audit-auth-access.sh` | Permission / role audit |
| `./scripts/qa/verify-oidc-provider-configs.sh` | Authentik OIDC provider configuration |

### 2.5 Database & Storage

| Script | Purpose |
|---|---|
| `./scripts/qa/verify-atlas-health.sh` | MongoDB Atlas connectivity + reachability |
| `./scripts/qa/verify-cloud-sql-snapshots.sh` | Cloud SQL automated snapshot recency |
| `./scripts/qa/audit-velero.sh` | Velero schedule + backup objects |
| `./scripts/qa/audit-atlas-allowlist-monitor.sh` | Atlas allowlist drift vs GKE NAT IPs |
| `./scripts/infra/ensure-atlas-allowlist-gke-nodes.sh` | Enforce GKE NAT IPs in Atlas allowlist |

### 2.6 Quick One-Liners (kubectl)

```bash
# Are pods running?
kubectl get pods -n mereka-lms

# Do all services have endpoints? (Empty = no traffic)
kubectl get endpoints -n mereka-lms

# Caddy LoadBalancer status
kubectl get svc caddy -n mereka-lms

# Recent events (shows OOMKills, scheduling failures, pull errors)
kubectl get events -n mereka-lms --sort-by=.lastTimestamp | tail -30

# LMS logs (last 50 lines)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50

# ArgoCD sync state
kubectl get app mereka-lms -n argocd -o jsonpath='{.status.sync.status}'
```

Full cheatsheet: [kubectl-cheatsheet.md](../../ops/quickref/kubectl-cheatsheet.md)

---

## 3. SLO Definitions Summary

Defined in [SLO_POLICY.md](../../policies/operations/SLO_POLICY.md). Quick reference:

| Service | Tier | Availability SLO | Latency p99 | Error budget (30d) |
|---|---|---|---|---|
| LMS | 1 | 99.95% | < 2 s | 21.6 min |
| Purchase Gateway | 1 | 99.95% | < 1 s | 21.6 min |
| Studio / CMS | 2 | 99.5% | < 3 s | 3.6 h |
| MFE / Caddy | 2 | 99.5% | < 500 ms (p95) | 3.6 h |
| Forum | 3 | 99.0% | < 2 s (p95) | 7.3 h |

Burn rate alerts fire when error budget consumption rate exceeds 1× (warning) or 6× (critical). See `deploy/k8s/base/monitoring/prometheusrule-slo.yaml` and `slo-burn-rate-rules.yaml`.

---

## 4. Escalation Matrix

| Tier | Symptom | Primary action | Escalation target | Time limit |
|---|---|---|---|---|
| L1 | Alert fires | Primary on-call acknowledges | — | 15 min |
| L2 | Primary unreachable or unresolved in 30 min | Secondary on-call takes over | — | 15 min to ack |
| L3 | Secondary unresolved in 1 hr | Engineering Lead becomes IC | — | 15 min to ack |
| L4 | Unresolved > 2 hr or confirmed data loss | VP/CTO notified | Immediate | — |

### By Issue Type

| Issue type | First action | If unresolved → escalate to |
|---|---|---|
| LMS / Studio fully down (P1) | `fix-service-selectors.sh` → check ArgoCD | Engineering Lead |
| Empty endpoints after restart | `fix-service-selectors.sh` | Engineering Lead if persists |
| MongoDB Atlas unreachable | Check Atlas console + IP allowlist | Engineering Lead + Atlas support |
| MySQL CrashLoopBackOff | Check PVC capacity, OOM events | Engineering Lead |
| ExternalSecret sync failure | Check ESO logs, Infisical → GCP SM pipeline | Secrets rotation SOP |
| TLS cert expired | `check-cert-sans.sh`, cert-manager status | Engineering Lead (data-risk if cert expired in prod) |
| Velero restore test failure | `audit-velero.sh`, DR runbook | Engineering Lead (data-risk) |
| Auth SSO broken | `verify-studio-sso-flow.sh`, Authentik admin | Engineering Lead |
| 5xx error rate spike | Check LMS logs → Prometheus → Grafana | Engineering Lead if > 10 min |
| Branding / UI regression | `public-health-check.sh`, visual smoke | Fix-forward; P4 unless enrolment affected |

Full on-call structure: [ONCALL_ROTATION.md](../../policies/operations/ONCALL_ROTATION.md)
Incident response workflow: [INCIDENT_RESPONSE.md](../../ops/runbooks/INCIDENT_RESPONSE.md)
Post-mortem template: [POST_MORTEM_TEMPLATE.md](../../meta/templates/POST_MORTEM_TEMPLATE.md)

---

## 5. Common Operator Workflows

### 5.1 "Is the site healthy?" (2 minutes)

```bash
# Step 1: external endpoints + certs
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod

# Step 2: k8s cluster state
kubectl get pods -n mereka-lms
kubectl get endpoints -n mereka-lms

# Step 3: observability gate
./scripts/qa/run-operations-gates.sh --env both
```

If all three pass: platform is healthy.
If any fail: proceed to section 2 scripts for the affected area.

### 5.2 Site Down Response (5–10 minutes)

Follow the decision tree in [site-down.md](../../ops/runbooks/site-down.md).

Quick path for the most common cause (service selector mismatch):
```bash
./scripts/infra/fix-service-selectors.sh
kubectl get endpoints -n mereka-lms   # confirm non-empty
```

If endpoints are populated but site still returns 502: check Caddy logs.
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50
```

### 5.3 New Operator Onboarding Checklist

Before an operator can respond to incidents independently, verify:

- [ ] `kubectl config use-context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` works
- [ ] Can open Grafana at https://grafana.mereka.io (Authentik login)
- [ ] Can access Django admin at https://academyv2.mereka.io/admin
- [ ] Can access Admin Console MFE at https://apps.academyv2.mereka.io/admin-console/
- [ ] Has read access to Infisical (secrets inventory)
- [ ] Has been added to `#mereka-operations` and `#mereka-incidents` Slack channels
- [ ] Has shadowed one on-call week before taking primary rotation

### 5.4 Post-Deployment Verification

After any Kubernetes deployment:
```bash
# Confirm rolling update completed
./scripts/infra/verify-deployment.sh

# Confirm endpoints are populated
kubectl get endpoints -n mereka-lms

# Run smoke tests
./scripts/qa/smoke-test.sh
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

Full checklist: [RELEASE_CHECKLIST.md](../../ops/runbooks/RELEASE_CHECKLIST.md) and [POST_DEPLOY_GATE.md](../../ops/runbooks/POST_DEPLOY_GATE.md).

---

## 6. What Dashboards Exist vs. What Is Still Needed

### Exists (confirmed)

| Dashboard / Tool | Status |
|---|---|
| Grafana: LMS Public Endpoints | Live — `bbi-app-mereka-lms` |
| Grafana: Operations Signals | Live — stateful storage + DB |
| Grafana: GKE pod resource view | Live |
| Grafana: Auth failure rates | Live |
| GCP Cloud Monitoring uptime checks | Live — `infrastructure/monitoring/uptime/` |
| GCP Cloud Monitoring alert policies | Live — `infrastructure/monitoring/alerts/` |
| PrometheusRules (15 files) | Deployed to `mereka-lms` namespace |
| Django admin panel | Live — standard Open edX |
| Admin Console MFE | Live — RBAC and org admin |
| Alertmanager alert routing | Live — `verify-alert-routing.sh` confirms |

### Not Yet Deployed / Gaps

| Item | Gap | Tracked by |
|---|---|---|
| Aspects / Superset analytics dashboard | Manifests exist, not deployed to any cluster | T148 |
| Operator "diagnostics page" (web UI) | No single-pane-of-glass web app for non-engineer operators | Not tracked (see note below) |
| Tenant health per-tenant breakdown in Grafana | Current dashboards show platform level only | Future work |
| Purchase Gateway Grafana panel | No dedicated Grafana panel; covered by PrometheusRules only | Future work |
| Mobile app monitoring | No Grafana panel for mobile API endpoints | Future work |

**Note on "diagnostics page"**: A browser-based diagnostics UI for non-engineer operators was considered as part of T129. The current state is that `scripts/qa/` provides comprehensive CLI-level diagnostics, the Grafana dashboards cover the monitoring use case, and the Admin Console MFE covers RBAC admin. A separate web diagnostics app would only add value once tenant-facing operators (non-engineers) need triage capability without kubectl access. This is deferred to a future spec.

---

## 7. Alert Tuning & Silence Rules

- **Never silence alerts permanently** — fix the threshold instead.
- Any change to an alert threshold requires a PR + reviewer approval.
- Data-risk alerts (Velero restore/verification, storage ENOSPC) require explicit senior approval before reducing sensitivity.
- Tune workflow: export last 7 days → classify → adjust one threshold → PR → re-apply with `./scripts/infra/apply-monitoring-configs.sh apply`.

Full SOP: [ALERT_TUNING_SOP.md](../../ops/runbooks/ALERT_TUNING_SOP.md)

---

## 8. Related Documentation Index

| Document | Purpose |
|---|---|
| [site-down.md](../../ops/runbooks/site-down.md) | Quick fixes for common symptoms |
| [OBSERVABILITY_QUICKSTART.md](../../ops/runbooks/OBSERVABILITY_QUICKSTART.md) | 2-minute health check script sequence |
| [ONCALL_OBSERVABILITY_PLAYBOOK.md](../../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md) | Structured on-call health sequence |
| [ONCALL_ROTATION.md](../../policies/operations/ONCALL_ROTATION.md) | On-call schedule and escalation structure |
| [INCIDENT_RESPONSE.md](../../ops/runbooks/INCIDENT_RESPONSE.md) | Incident declaration and triage workflow |
| [INCIDENT_TEMPLATES.md](../../ops/runbooks/INCIDENT_TEMPLATES.md) | Copy-paste incident declaration + postmortem templates |
| [ALERT_SEVERITY_MATRIX.md](ALERT_SEVERITY_MATRIX.md) | Full alert → severity → routing mapping |
| [ALERT_TUNING_SOP.md](../../ops/runbooks/ALERT_TUNING_SOP.md) | How to tune alert thresholds safely |
| [SLO_POLICY.md](../../policies/operations/SLO_POLICY.md) | SLO targets and error budget policy |
| [SLO_DASHBOARDS_SETUP.md](../../ops/runbooks/SLO_DASHBOARDS_SETUP.md) | Grafana SLO dashboard architecture |
| [ADMIN_CONSOLE_SETUP.md](ADMIN_CONSOLE_SETUP.md) | Admin Console MFE access and capabilities |
| [ASPECTS_ANALYTICS_SETUP.md](ASPECTS_ANALYTICS_SETUP.md) | Aspects/Superset analytics (future) |
| [emergency-rollback.md](../../ops/runbooks/emergency-rollback.md) | GitOps rollback procedure |
| [DISASTER_RECOVERY.md](../../ops/runbooks/DISASTER_RECOVERY.md) | Full DR procedure |
| [kubectl-cheatsheet.md](../../ops/quickref/kubectl-cheatsheet.md) | kubectl commands reference |
| [access-urls.md](../../ops/quickref/access-urls.md) | All environment URLs (local, dev, prod) |
| [CAPACITY_PLANNING.md](CAPACITY_PLANNING.md) | Pod resource limits, HPA config, load test baselines |
