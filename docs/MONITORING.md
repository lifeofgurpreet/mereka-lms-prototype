# Monitoring & Alerting Guide

This checklist focuses on the GKE Autopilot cluster, Cloud SQL, and Memorystore that run the Mereka LMS staging stack.

## Dashboards

1. **GKE Autopilot**
   - Metrics: `kubernetes.io/container/cpu/request_utilization`, `kubernetes.io/container/memory/request_utilization`, `kubernetes.io/container/restart_count`, `ingress.googleapis.com/https/request_count`.
   - Filter by namespace `mereka-lms`.
   - Add a log panel for `k8s_container` severity `ERROR` (namespace `mereka-lms`).

2. **Cloud SQL (MySQL)**
   - Metrics: `cloudsql.googleapis.com/database/cpu/utilization`, `cloudsql.googleapis.com/database/memory/utilization`, `cloudsql.googleapis.com/database/disk/utilization`, `cloudsql.googleapis.com/database/replication/lag`.
   - Enable “Query Insights” in the Cloud SQL console for slow-query heatmaps.

3. **Memorystore (Redis)**
   - Metrics: `redis.googleapis.com/stats/memory/used_bytes` vs `maxmemory`, `redis.googleapis.com/stats/commands/ops`, `redis.googleapis.com/stats/network/bytes`.

> JSON templates live under `ops/monitoring/dashboards/` (`gke.json`, `cloudsql.json`, `redis.json`). Apply them with  
> `gcloud monitoring dashboards create --config-from-file ops/monitoring/dashboards/gke.json`

## Alerting Policies

Minimum recommended policies (edit thresholds as desired):

| Alert | JSON template | Notes |
|-------|---------------|-------|
| GKE pod restarts | `ops/monitoring/alerts/pod-restarts.json` | Threshold: >5 restarts / pod within 10 min. |
| Ingress 5xx spike | `ops/monitoring/alerts/lb-5xx-ratio.json` | Update the `url_map_name` if GKE creates a different LB. |
| Cloud SQL disk utilization | `ops/monitoring/alerts/cloudsql-disk.json` | Fires when disk usage >80% for 5 min. |

Apply an alert with:  
`gcloud monitoring policies create --policy-from-file ops/monitoring/alerts/pod-restarts.json`

Create via Console (Monitoring → Alerting) or `gcloud monitoring policies create --policy-from-file alert.json`. When using `gcloud`, populate `notification_channels` with email/SMS/webhook IDs.

## Logging & Tracing

- Enable Cloud Logging sinks to BigQuery if long-term retention is required (`gcloud logging sinks create …`).
- For SMTP delivery issues, monitor AWS SES dashboards (CloudWatch) and set SNS notifications on bounces/complaints.

## Operational Runbook Tips

1. **On-call checks** – keep `./tools/smoke-test.sh` handy for immediate verification.
2. **Pod deep dive** – `kubectl logs -n mereka-lms deployment/<service>` for each microservice noted in alerts.
3. **Cloud SQL failover** – confirm automatic backups are successful (Cloud SQL → Backups). Manual export script lives in `tools/backup-db.sh`.

> Update this file as you add dashboards/alerts so the next engineer knows which policies exist and where they live.
