<!-- @spec: cross-cutting-requirements_spec.md -->
# On-Call Guide

_Audience: Engineers on rotation · Owner: Engineering Lead · Last updated: 2026-02-24_

This document is the quick reference for whoever is currently on-call. For the full rotation schedule and role definitions, see [ONCALL_ROTATION.md](ONCALL_ROTATION.md).

**Incident response procedures**: [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md)

---

## Current On-Call (Fill In Each Week)

| Role | Name | Contact | Week |
|------|------|---------|------|
| Primary | _@name_ | _Slack / phone_ | _YYYY-MM-DD to YYYY-MM-DD_ |
| Secondary | _@name_ | _Slack / phone_ | _YYYY-MM-DD to YYYY-MM-DD_ |
| Incident Commander | Engineering Lead | _Slack / phone_ | Permanent |

> **Canonical schedule**: pinned in `#mereka-operations` Slack. This table is a backup reference only.

---

## Responsibilities During On-Call

1. **Respond to alerts** within 15 min (P1) or 30 min (P2). See [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) for severity definitions.
2. **Triage and diagnose** — do not just restart pods; identify the root cause.
3. **Communicate** — post in `#mereka-incidents` immediately on P1/P2. Update every 15-30 min.
4. **Escalate** — if unresolved after 15 min with no path forward, page secondary and/or IC.
5. **Document** — after resolution, ensure incident is logged and postmortem is scheduled if required.

---

## Shift Handoff Checklist

Complete before ending your on-call shift:

- [ ] Check Alertmanager for any silenced/pending alerts: https://alertmanager.mereka.dev
- [ ] Check ArgoCD for any OutOfSync apps: `kubectl get app -n argocd`
- [ ] Verify no open incidents in `#mereka-incidents`
- [ ] Check pod health: `kubectl get pods -n mereka-lms | grep -v Running | grep -v Completed`
- [ ] Ensure any workarounds applied during shift have corresponding git commits
- [ ] Brief incoming on-call in `#mereka-operations` with shift summary (even if quiet)
- [ ] Update on-call schedule if there were any coverage changes

---

## Monitoring Dashboards

Check these first when starting a shift or responding to an alert:

| Dashboard | URL | What to Look For |
|-----------|-----|-----------------|
| Prometheus | https://prometheus.mereka.dev | `http_requests_total`, error rates, LMS latency |
| Alertmanager | https://alertmanager.mereka.dev | Active/pending alerts, silences |
| Loki logs | https://loki.mereka.dev | Recent errors across services |
| Tempo traces | https://tempo.mereka.dev | Slow requests, DB query times |
| Upptime status page | https://status.mereka.dev | External uptime checks |

**Quick health check** (run from repo root):
```bash
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

---

## Alert Routing

| Alert | Default Recipient | Escalates To |
|-------|------------------|-------------|
| `LMSDown` | Primary on-call | IC after 15 min |
| `CertificateExpiringSoon` | Primary on-call | IC if <7 days |
| `MongoDBAtlasUnreachable` | Primary on-call | IC after 15 min |
| `HighErrorRate` (>5%) | Primary on-call | IC after 30 min |
| `PodCrashLooping` | Primary on-call | Secondary after 30 min |
| `ESO SyncFailed` | Primary on-call | IC if secrets affected |
| `VeleroBackupFailed` | Secondary on-call | IC if >24hr without backup |

> Alert routing config lives in Alertmanager. Verify with: `./scripts/qa/verify-alert-routing.sh`

---

## Escalation Timeframes

| Severity | Primary Response | Escalate to Secondary | Escalate to IC |
|----------|-----------------|----------------------|----------------|
| P1 | 15 min | +15 min (no response) | +15 min (no secondary response) |
| P2 | 30 min | +30 min | +30 min |
| P3 | 2 hours | — | Next business day |
| P4 | Next business day | — | — |

---

## Tools Required

Ensure you have access to these before your shift starts:

| Tool | Access Method | Purpose |
|------|--------------|---------|
| `kubectl` | GKE credentials: `gcloud container clusters get-credentials ...` | Pod/service management |
| GCP Console | https://console.cloud.google.com (project: `bbi-k8`) | Cloud SQL, Secret Manager, Artifact Registry |
| Infisical | https://secrets.mereka.io | Source-of-truth for secrets |
| ArgoCD | `kubectl port-forward svc/argocd-server -n argocd 8080:443` | GitOps sync status |
| Slack | `#mereka-incidents`, `#mereka-operations` | Communication |
| Repo access | `git clone` with push rights | GitOps fixes (ArgoCD enforced) |

**Verify cluster access**:
```bash
kubectl get nodes
kubectl get pods -n mereka-lms | grep -v Running
```

---

## If You Get Paged

1. Acknowledge the alert in Alertmanager / PagerDuty immediately.
2. Open [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) — follow from Step 1.
3. Run the 5-command diagnostic from the repo root.
4. If site is down, start with `./scripts/infra/fix-service-selectors.sh`.
5. Post in `#mereka-incidents` within 5 minutes of acknowledgement.

---

## References

- Full rotation rules: [ONCALL_ROTATION.md](ONCALL_ROTATION.md)
- Incident procedures: [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md)
- Communication templates: [INCIDENT_TEMPLATES.md](INCIDENT_TEMPLATES.md)
- Observability quick-start: [ONCALL_OBSERVABILITY_PLAYBOOK.md](ONCALL_OBSERVABILITY_PLAYBOOK.md)
- Site-down runbook: [../ops/runbooks/site-down.md](../ops/runbooks/site-down.md)
- Emergency rollback: [../ops/runbooks/emergency-rollback.md](../ops/runbooks/emergency-rollback.md)
