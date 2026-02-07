# Alert Severity Matrix
_Audience: On-call + SRE • Last updated: 2026-02-06_

## Severity Definitions

- `ERROR`: Immediate operator action required; user-facing impact or data-risk likely.
- `WARNING`: Degradation or precursor signal; action required within business hours.

## Current Mapping (Mereka LMS)

| Alert | File | Severity | Routing intent |
|------|------|----------|----------------|
| TLS certificate expiry | `infrastructure/monitoring/alerts/https-cert-expiry.json` | ERROR | Immediate |
| Ingress 5xx spike | `infrastructure/monitoring/alerts/lb-5xx-ratio.json` | ERROR | Immediate |
| App 5xx spike | `infrastructure/monitoring/alerts/log-5xx-spike.json` | ERROR | Immediate |
| Auth verify CronJob failures | `infrastructure/monitoring/alerts/log-auth-verify-cronjob-failures.json` | ERROR | Immediate |
| Cert verify CronJob failures | `infrastructure/monitoring/alerts/log-cert-verify-cronjob-failures.json` | ERROR | Immediate |
| Stateful storage errors | `infrastructure/monitoring/alerts/log-stateful-storage-errors.json` | ERROR | Immediate |
| Velero backup verification failures | `infrastructure/monitoring/alerts/log-velero-backup-verification-failures.json` | ERROR | Immediate |
| Velero restore-test failures | `infrastructure/monitoring/alerts/log-velero-restore-test-failures.json` | ERROR | Immediate |
| Velero backup verification stale (no success in 30h) | `infrastructure/monitoring/alerts/velero-backup-verification-stale.json` | ERROR | Immediate |
| Velero restore-test stale (no success in 45d) | `infrastructure/monitoring/alerts/velero-restore-test-stale.json` | ERROR | Immediate |
| Pod restarts | `infrastructure/monitoring/alerts/pod-restarts.json` | WARNING | Business-hours triage unless sustained |
| PVC utilization high | `infrastructure/monitoring/alerts/pvc-utilization-high.json` | WARNING | Business-hours triage; escalate early for stateful services |
| MySQL saturation high | `infrastructure/monitoring/alerts/mysql-saturation-high.json` | WARNING | Business-hours triage unless sustained / user impact |
| Redis saturation high | `infrastructure/monitoring/alerts/redis-saturation-high.json` | WARNING | Business-hours triage unless sustained / user impact |
| MySQL connection errors | `infrastructure/monitoring/alerts/log-mysql-connection-errors.json` | WARNING | Business-hours triage unless sustained |
| Redis connection errors | `infrastructure/monitoring/alerts/log-redis-connection-errors.json` | WARNING | Business-hours triage unless sustained |
| Auth failure spikes (LMS/credentials/forum) | `infrastructure/monitoring/alerts/log-auth-failures*.json` | WARNING | Investigate auth drift |
| LMS OIDC provider disabled | `infrastructure/monitoring/alerts/log-lms-oidc-provider-disabled.json` | ERROR | Immediate (SSO outage risk) |
| LMS CSRF failures spike | `infrastructure/monitoring/alerts/log-lms-csrf-failures.json` | WARNING | Business-hours triage unless login blocked |
| Critical deployment unavailable replicas | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` (`OpenEdxCriticalDeploymentUnavailable`) | ERROR | Immediate |
| CrashLoopBackOff in `mereka-lms` | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` (`OpenEdxCrashLoopingContainers`) | ERROR | Immediate |
| Pods pending too long | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` (`OpenEdxPodsPendingTooLong`) | WARNING | Business-hours triage unless user impact |
| Synthetic/backup job failures (`auth-verify`, `cert-verify`, `backup-verification`, `restore-test`) | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` (`OpenEdxSyntheticOrBackupJobFailures`) | WARNING | Triage same day; escalate if repeated |

## Escalation Rules

1. If an alert is `ERROR` and confirmed in metrics/logs, declare incident.
2. If `WARNING` repeats 3+ intervals consecutively, treat as incident candidate.
3. Any storage/Velero signal crossing threshold is escalated as data-risk.
