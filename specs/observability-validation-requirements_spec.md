---
title: "Observability Validation & SLI/SLO Compliance Requirements"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-13"
version: "1.0.0"
depends_on:
  - "specs/observability-stack_spec.md"
  - "specs/slo-sla-service-level-management_spec.md"
  - "specs/cross-cutting-requirements_spec.md"
  - "specs/k8s-deployment_spec.md"
links:
  related_docs:
    - "docs/operations/OBSERVABILITY_GUIDE.md"
    - "docs/operations/MONITORING.md"
    - "docs/operations/SLO_DASHBOARDS_SETUP.md"
    - "docs/operations/ALERT_SEVERITY_MATRIX.md"
    - "docs/operations/ALERT_TUNING_SOP.md"
    - "docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/operations/TROUBLESHOOTING.md"
  related_specs:
    - "specs/observability-stack_spec.md"
    - "specs/slo-sla-service-level-management_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
---

# Human Summary

## What we're building

A compliance and validation specification that defines the exact set of Prometheus alerts, ServiceMonitors, PrometheusRules, GCP Monitoring resources, SLI recording rules, and Grafana dashboards that MUST exist in the Mereka Academy production environment. This spec serves as the machine-checkable contract for observability completeness -- it does not define the observability stack itself (that is `observability-stack_spec.md`) or the SLO targets (that is `slo-sla-service-level-management_spec.md`). Instead, it specifies: "given those specs, here is exactly what must be deployed, how to verify it, and what happens when something is missing."

## Why it matters

The Mereka Academy platform has three separate specs that touch observability: the observability stack spec (infrastructure), the SLO/SLA spec (targets and processes), and the cross-cutting requirements spec (baseline per-service requirements). However, none of them define a single, verifiable checklist that answers: "Are all required monitors actually deployed? Are all required alerts actually firing? Are all SLI recording rules producing data?" Without this spec, observability drift is discovered only during incidents -- when a missing alert means a failure goes undetected. This spec makes observability compliance a CI-gatable, auditable, repeatable check.

## Success looks like

- A single script (`scripts/qa/validate-observability-compliance.sh`) returns PASS/FAIL for the entire observability contract
- Every production service in `mereka-lms` has a ServiceMonitor, a set of alert rules, and a Grafana dashboard panel -- verifiable by running the script
- Every SLI recording rule defined in the SLO spec is producing data in Prometheus -- verifiable by querying the recording rule names
- Missing observability artifacts block deployment via CI gate (when enabled)
- New services cannot be deployed without a corresponding ServiceMonitor and alert rules in the monitoring kustomization
- The compliance report can be generated in both human-readable and JSON formats for audit purposes

# Agent Contract

## Scope

- In scope:
  - Required ServiceMonitors: which services MUST have a ServiceMonitor, with what configuration
  - Required PrometheusRules: which alert rules MUST exist, organized by service and severity
  - Required SLI recording rules: which recording rules MUST exist and produce valid data
  - Required GCP Monitoring resources: uptime checks, log-based metrics, alert policies, dashboards
  - Required Grafana dashboards and panels: which dashboards MUST exist with which panels
  - Validation scripts: specification of what the compliance validation script must check
  - CI integration: how observability compliance is gated in the deployment pipeline
  - Compliance reporting: format and contents of the compliance report
- Out of scope:
  - Deploying the observability stack (covered by `specs/observability-stack_spec.md`)
  - Defining SLO targets or error budget calculation (covered by `specs/slo-sla-service-level-management_spec.md`)
  - Alert routing configuration (Slack channels, PagerDuty, email) -- that is operational config
  - Grafana user/team management
  - Application-level instrumentation (django-prometheus installation)
  - Third-party SaaS monitoring integrations

## Non-goals

- Replacing the existing `audit-observability.sh` script -- this spec extends its contract, not replaces it
- Defining new SLO targets or changing existing ones
- Specifying the implementation of Prometheus, Loki, Tempo, or Grafana
- Mandating specific PromQL expressions (expressions are illustrative; the recording rule names and labels are the contract)
- Automating remediation of missing observability artifacts (this spec detects gaps, humans fix them)

## Assumptions

- GKE cluster `bbi-k8-cluster` in `asia-southeast1-c` with namespace `mereka-lms` is the production target
- Prometheus Operator (kube-prometheus-stack) is deployed in the `monitoring` namespace
- Prometheus discovers ServiceMonitor and PrometheusRule CRDs from the `mereka-lms` namespace
- GCP Cloud Monitoring is the external monitoring layer (uptime checks, alert policies)
- VPS Prometheus at `prometheus.mereka.dev` provides blackbox exporter probes
- Grafana is deployed at `grafana.mereka.io` with Prometheus datasources configured
- The kustomization at `deploy/k8s/base/monitoring/kustomization.yaml` is the source of truth for in-cluster monitoring resources
- The directory `infrastructure/monitoring/` is the source of truth for GCP Monitoring resources
- Existing audit scripts (`scripts/qa/audit-observability.sh`, `scripts/qa/audit-grafana-dashboard.sh`, `scripts/qa/audit-db-exporter-telemetry.sh`) will continue to operate alongside the new compliance script
- django-prometheus is a prerequisite for application-level SLI recording rules but is not yet deployed (the compliance script must report this as a known gap, not a hard failure, until deployment)

## Requirements

### Required ServiceMonitors

The system MUST maintain a ServiceMonitor for every production service in the `mereka-lms` namespace that exposes an HTTP endpoint. The following table defines the required ServiceMonitors:

| ServiceMonitor Name | Target Service | Port | Path | Interval | Status |
|---------------------|---------------|------|------|----------|--------|
| `lms-metrics` | LMS | `http` (8000) | `/metrics` | 30s | Deployed |
| `cms-metrics` | CMS (Studio) | `http` (8000) | `/metrics` | 30s | Deployed |
| `mysql-metrics` | MySQL exporter | `metrics` (9104) | `/metrics` | 30s | Deployed |
| `redis-metrics` | Redis exporter | `metrics` (9121) | `/metrics` | 30s | Deployed |
| `enterprise-catalog-metrics` | Enterprise Catalog | `http` | `/metrics` | 30s | Deployed |
| `enterprise-access-metrics` | Enterprise Access | `http` | `/metrics` | 30s | Deployed |
| `enterprise-subsidy-metrics` | Enterprise Subsidy | `http` | `/metrics` | 30s | Deployed |
| `caddy-metrics` | Caddy reverse proxy | `metrics` (2019) | `/metrics` | 30s | Required |
| `mfe-metrics` | Micro-frontends | `http` | `/metrics` | 30s | Required |
| `forum-metrics` | Forum (openedx-forum) | `http` | `/metrics` | 30s | Required |
| `discovery-metrics` | Discovery (catalog) | `http` | `/metrics` | 30s | Required |
| `ecommerce-metrics` | Ecommerce | `http` | `/metrics` | 30s | Required |
| `credentials-metrics` | Credentials | `http` | `/metrics` | 30s | Required |
| `purchase-gateway-metrics` | Purchase Gateway | `http` (8000) | `/metrics` | 30s | Required |

- The system MUST deploy all ServiceMonitors listed with status "Required" to achieve full coverage
- Every ServiceMonitor MUST be listed in `deploy/k8s/base/monitoring/kustomization.yaml`
- Every ServiceMonitor MUST use the label `app.kubernetes.io/component: monitoring`
- Every ServiceMonitor MUST include relabeling rules to add `pod`, `node`, and `namespace` labels
- The scrape timeout MUST be <= 10 seconds for all ServiceMonitors
- The system SHOULD deploy ServiceMonitors for Notes and XQueue when those services are promoted to production workloads

### Required PrometheusRule Alert Groups

The system MUST maintain PrometheusRule CRDs that define alert rules for every production service. The following table defines the required alert rules organized by PrometheusRule resource:

#### `prometheusrule-lms.yaml` (Deployed)

| Alert Name | Severity | Condition Summary | For Duration |
|------------|----------|-------------------|--------------|
| `LMSPodDown` | critical | LMS scrape target down | 5m |
| `LMSPodRestarting` | warning | LMS pod restart rate > 0 in 15m | 5m |
| `LMSPodMemoryHigh` | warning | Memory > 85% of limit | 10m |
| `LMSPodMemoryCritical` | critical | Memory > 95% of limit (OOM risk) | 5m |
| `LMSPodCPUHigh` | warning | CPU > 85% of limit | 10m |
| `LMSPodDiskSpaceHigh` | warning | PV disk > 85% of capacity | 10m |
| `CMSPodDown` | critical | CMS scrape target down | 5m |
| `CMSPodMemoryHigh` | warning | CMS memory > 85% of limit | 10m |
| `MySQLPodDown` | critical | MySQL pod down | 5m |
| `MySQLExporterDown` | critical | MySQL exporter target down | 5m |
| `MySQLHighConnectionUtilization` | warning | threads_connected/max_connections > 85% | 10m |
| `MySQLSlowQueriesSpike` | warning | Slow queries increase > 20 in 10m | 10m |
| `RedisPodDown` | critical | Redis pod down | 5m |
| `RedisExporterDown` | critical | Redis exporter target down | 5m |
| `RedisRejectedConnectionsSpike` | warning | Rejected connections > 0 in 10m | 10m |
| `RedisEvictionsSpike` | warning | Evicted keys > 0 in 15m | 10m |
| `MongoDBPodDown` | critical | MongoDB pod down | 5m |
| `ElasticsearchPodDown` | warning | Elasticsearch pod down | 5m |
| `OpenEdxCriticalDeploymentUnavailable` | critical | Any critical deployment has unavailable replicas | 10m |
| `OpenEdxPodsPendingTooLong` | warning | Pods stuck in Pending > 15m | 15m |
| `OpenEdxCrashLoopingContainers` | critical | CrashLoopBackOff detected | 10m |
| `OpenEdxSyntheticOrBackupJobFailures` | warning | Synthetic/backup job failures in 6h | 5m |

#### `prometheusrule-enterprise.yaml` (Deployed)

| Alert Name | Severity | Condition Summary | For Duration |
|------------|----------|-------------------|--------------|
| `EnterpriseCatalogPodDown` | critical | Enterprise Catalog scrape target down | 5m |
| `EnterpriseCatalogPodRestarting` | warning | Pod restart rate > 0 in 15m | 5m |
| `EnterpriseCatalogMemoryHigh` | warning | Memory > 85% of limit | 10m |
| `EnterpriseCatalogCPUHigh` | warning | CPU > 85% of limit | 10m |
| `EnterpriseAccessPodDown` | critical | Enterprise Access scrape target down | 5m |
| `EnterpriseAccessPodRestarting` | warning | Pod restart rate > 0 in 15m | 5m |
| `EnterpriseAccessMemoryHigh` | warning | Memory > 85% of limit | 10m |
| `EnterpriseAccessCPUHigh` | warning | CPU > 85% of limit | 10m |
| `EnterpriseSubsidyPodDown` | critical | Enterprise Subsidy scrape target down | 5m |
| `EnterpriseSubsidyPodRestarting` | warning | Pod restart rate > 0 in 15m | 5m |
| `EnterpriseSubsidyMemoryHigh` | warning | Memory > 85% of limit | 10m |
| `EnterpriseSubsidyCPUHigh` | warning | CPU > 85% of limit | 10m |

#### `prometheusrule-velero.yaml` (Deployed)

| Alert Name | Severity | Condition Summary | For Duration |
|------------|----------|-------------------|--------------|
| `VeleroBackupFailed` | critical | Backup failure in last 1h | 5m |
| `VeleroBackupMissing` | warning | No successful backup in 24h | 10m |

#### `prometheusrule-slo.yaml` (Deployed)

| Alert Name | Severity | Condition Summary | For Duration |
|------------|----------|-------------------|--------------|
| `SLOBudgetFastBurn` | critical | 1h burn > 14.4x AND 5m burn > 14.4x (Tier 1) | 2m |
| `SLOBudgetSlowBurn` | warning | 6h burn > 6x AND 30m burn > 6x (Tier 1) | 5m |
| `SLOBudgetWarning` | warning | 6h burn > 3x (any tier) | 30m |
| `SLOBudgetExhausted` | critical | Error budget remaining <= 0% (Tier 1) | 5m |
| `SLOBudgetLow` | warning | Error budget remaining < 25% (Tier 1) | 10m |
| `SLIMeasurementDown` | warning | No SLI data for Tier 1 service for 10m | 1m |

#### `prometheusrule-auth.yaml` (Deployed)

| Alert Name | Severity | Condition Summary | For Duration |
|------------|----------|-------------------|--------------|
| `AuthFailureRateHigh` | critical | Auth endpoint 401/403 rate > 10% in 5m | 5m |
| `SSOLoginLatencyHigh` | warning | Auth endpoint p95 latency > 2s | 10m |
| `MFAChallengeFailureRate` | warning | MFA challenge failure rate > 20% in 15m | 15m |
| `SessionStoreUnavailable` | critical | Redis session backend errors or down | 2m |
| `SCIMWebhookErrors` | warning | SCIM endpoint returning 5xx | 10m |
| `EnterpriseIdPUnreachable` | warning | SAML metadata refresh failing | 30m |

#### Required New Alerts (Not Yet Deployed)

The system MUST add the following alert rules to achieve compliance with the SLO and cross-cutting specs:

| Alert Name | PrometheusRule | Severity | Condition Summary | For Duration |
|------------|---------------|----------|-------------------|--------------|
| `CaddyHighErrorRate` | `prometheusrule-caddy.yaml` | critical | Caddy 5xx rate > 1% of total requests in 5m | 5m |
| `CaddyHighLatency` | `prometheusrule-caddy.yaml` | warning | Caddy p95 upstream latency > 2s for 10m | 10m |
| `CaddyDown` | `prometheusrule-caddy.yaml` | critical | Caddy pod down | 3m |
| `ForumPodDown` | `prometheusrule-services.yaml` | warning | Forum pod down | 5m |
| `DiscoveryPodDown` | `prometheusrule-services.yaml` | warning | Discovery pod down | 5m |
| `EcommercePodDown` | `prometheusrule-services.yaml` | warning | Ecommerce pod down | 5m |
| `CredentialsPodDown` | `prometheusrule-services.yaml` | warning | Credentials pod down | 5m |
| `MFEPodDown` | `prometheusrule-services.yaml` | warning | MFE pod down | 5m |
| `PurchaseGatewayPodDown` | `prometheusrule-services.yaml` | critical | Purchase Gateway pod down | 5m |
| `PurchaseGatewayHighErrorRate` | `prometheusrule-services.yaml` | critical | Purchase Gateway 5xx rate > 0.5% in 5m | 5m |
| `HighPVCUtilization` | `prometheusrule-lms.yaml` | warning | Any PVC in mereka-lms > 80% full | 10m |
| `LatencyRegressionSpike` | `prometheusrule-slo.yaml` | warning | p95 latency > 2x 7-day baseline for 15m | 15m |
| `LatencyRegressionDrift` | `prometheusrule-slo.yaml` | warning | p95 latency > 1.5x 7-day baseline for 1h | 1h |
| `ErrorRateSpike` | `prometheusrule-slo.yaml` | critical | 5xx rate > 3x 7-day average for 10m | 10m |

- Every PrometheusRule MUST be listed in `deploy/k8s/base/monitoring/kustomization.yaml`
- Every PrometheusRule MUST carry the label `prometheus: kube-prometheus` to be discovered by the Prometheus Operator
- Every alert rule MUST include `severity` and `component` labels
- Every alert rule MUST include `summary` and `description` annotations
- The system MUST NOT delete or weaken existing deployed alert rules without documented justification and approval

### Required SLI Recording Rules

The system MUST maintain Prometheus recording rules that produce SLI metrics for SLO compliance tracking. The following recording rules MUST exist and produce valid data:

| Recording Rule Name | Labels Required | Window | Source |
|---------------------|-----------------|--------|--------|
| `mereka:http_requests:availability_ratio_5m` | `service`, `tier` | 5m | `prometheusrule-slo.yaml` |
| `mereka:http_requests:availability_ratio_30m` | `service`, `tier` | 30m | `prometheusrule-slo.yaml` |
| `mereka:http_requests:availability_ratio_1h` | `service`, `tier` | 1h | `prometheusrule-slo.yaml` |
| `mereka:http_requests:availability_ratio_6h` | `service`, `tier` | 6h | `prometheusrule-slo.yaml` |
| `mereka:http_request_duration:p50_5m` | `service` | 5m | `prometheusrule-slo.yaml` |
| `mereka:http_request_duration:p95_5m` | `service` | 5m | `prometheusrule-slo.yaml` |
| `mereka:http_request_duration:p99_5m` | `service` | 5m | `prometheusrule-slo.yaml` |
| `mereka:slo:burn_rate_5m` | `service`, `tier` | 5m | `prometheusrule-slo.yaml` |
| `mereka:slo:burn_rate_30m` | `service`, `tier` | 30m | `prometheusrule-slo.yaml` |
| `mereka:slo:burn_rate_1h` | `service`, `tier` | 1h | `prometheusrule-slo.yaml` |
| `mereka:slo:burn_rate_6h` | `service`, `tier` | 6h | `prometheusrule-slo.yaml` |
| `mereka:slo:error_budget_remaining_ratio` | `service`, `tier` | 30d | `prometheusrule-slo.yaml` |
| `mereka:slo:error_budget_remaining_minutes` | `service`, `tier` | 30d | `prometheusrule-slo.yaml` |

- Recording rules MUST exist for both `lms` and `cms` services at minimum (Tier 1)
- Recording rules SHOULD exist for Tier 2 services (MFE, Forum, Discovery, Ecommerce, Credentials) when those services expose django-prometheus or equivalent metrics
- The system MUST alert via `SLIMeasurementDown` if any Tier 1 recording rule produces no data for 10 minutes
- Recording rules MUST be evaluated at the intervals specified in the SLO spec: 30s for SLI ratios, 60s for burn rates, 5m for error budget

### Required GCP Monitoring Resources

The system MUST maintain GCP Cloud Monitoring resources as defined in `infrastructure/monitoring/`. The following categories of resources MUST be present:

#### Uptime Checks

| Check Name | Target | Protocol | Check Interval |
|------------|--------|----------|----------------|
| `prod-lms-https` | `academyv2.mereka.io` | HTTPS | 5m |
| `prod-studio-https` | `studio.academyv2.mereka.io` | HTTPS | 5m |
| `prod-apps-https` | `apps.academyv2.mereka.io` | HTTPS | 5m |
| `prod-biji-https` | `academy.biji-biji.com` | HTTPS | 5m |
| `prod-skillourfuture-https` | `skillourfuture.mereka.io` or equivalent | HTTPS | 5m |
| `prod-discovery-https` | Discovery service endpoint | HTTPS | 5m |
| `prod-ecommerce-https` | Ecommerce service endpoint | HTTPS | 5m |
| `prod-credentials-https` | Credentials service endpoint | HTTPS | 5m |
| `prod-notes-https` | Notes service endpoint | HTTPS | 5m |
| `prod-forum-https` | Forum service endpoint | HTTPS | 5m |
| `prod-mfe-login` | MFE login page | HTTPS | 5m |
| `prod-mfe-account` | MFE account page | HTTPS | 5m |
| `prod-mfe-dashboard` | MFE dashboard page | HTTPS | 5m |

- Every uptime check MUST have a corresponding JSON definition in `infrastructure/monitoring/uptime/`
- The validation script MUST verify that every JSON file in `infrastructure/monitoring/uptime/` has a corresponding GCP resource
- The system MUST alert when any Tier 1 uptime check fails from 2+ probe regions

#### GCP Alert Policies

- Every JSON file in `infrastructure/monitoring/alerts/` MUST have a corresponding alert policy in GCP Monitoring
- The system MUST maintain alert policies for:
  - Load balancer 5xx ratio exceeding threshold
  - Cloud SQL disk utilization exceeding 80%
  - Pod restart count exceeding threshold
  - HTTPS certificate expiry within 14 days
  - Log-based alerts for auth failures, CSRF failures, storage errors, MySQL/Redis connection errors
  - Velero backup verification and restore test failures/staleness

#### Log-Based Metrics

- Every JSON file in `infrastructure/monitoring/logging-metrics/` MUST have a corresponding log-based metric in GCP Logging
- Required log-based metrics MUST include:
  - HTTP 5xx error counting
  - Authentication failure tracking (LMS, Forum, Credentials, Authentik)
  - OIDC provider disabled events
  - CSRF failure tracking
  - Stateful storage errors
  - MySQL and Redis connection errors
  - Velero backup/restore success and failure tracking

#### GCP Dashboards

- Every JSON file in `infrastructure/monitoring/dashboards/` MUST have a corresponding dashboard in GCP Monitoring
- Required dashboards: GKE overview, Redis metrics, Auth metrics, Public endpoints, Operations signals

### Required Grafana Dashboards

The system MUST maintain Grafana dashboards as defined in the dashboard coverage contract (`infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`).

- The dashboard with UID `bbi-app-mereka-lms` MUST exist in Grafana
- Required panels MUST include: LMS, CMS (Studio), Caddy, MySQL, Redis, LMS Availability (24h), Auth Failures Over Time, Recent Errors
- Required query fragments MUST include: `kube_pod_status_phase`, `container_cpu_usage_seconds_total`, `container_memory_usage_bytes`
- Recommended panels SHOULD include: Velero Backup Verification, Velero Restore Drill, CrashLooping Pods, Pending Pods, Critical Deployment Availability, Synthetic Job Failures, MySQL Connection Utilization, MySQL Slow Queries, Redis Rejected Connections, Redis Evictions
- The SLO dashboard (UID `mereka-slo-overview`) MUST exist with panels for per-service availability, error budget remaining, burn rate trends, and latency percentiles (per `slo-sla-service-level-management_spec.md` AC-008)

### Validation Script Requirements

The system MUST provide a compliance validation script at `scripts/qa/validate-observability-compliance.sh` that:

- The script MUST accept `--mode local|runtime|all` to control scope (local = repo checks only, runtime = live cluster + GCP checks, all = both)
- The script MUST accept `--json` flag for machine-readable output
- The script MUST accept `--strict` flag to fail on warnings (for CI gates)
- The script MUST return exit code 0 on full compliance and non-zero on any failure
- The script MUST NOT modify any cluster state (read-only audit)

**Local mode checks** (no cluster access required):
- The script MUST verify all required ServiceMonitor YAML files exist in `deploy/k8s/base/monitoring/`
- The script MUST verify all required PrometheusRule YAML files exist in `deploy/k8s/base/monitoring/`
- The script MUST verify all required files are listed in `deploy/k8s/base/monitoring/kustomization.yaml`
- The script MUST verify all JSON files in `infrastructure/monitoring/` are valid JSON
- The script MUST verify the Grafana dashboard contract file exists and is valid JSON
- The script MUST verify every ServiceMonitor has `interval: 30s` and `scrapeTimeout` <= 10s
- The script MUST verify every PrometheusRule has `prometheus: kube-prometheus` label

**Runtime mode checks** (requires cluster and GCP access):
- The script MUST verify all expected ServiceMonitor CRDs exist in the `mereka-lms` namespace via `kubectl get servicemonitor`
- The script MUST verify all expected PrometheusRule CRDs exist in the `mereka-lms` namespace via `kubectl get prometheusrule`
- The script MUST verify Prometheus has loaded all expected alert rules by querying `/api/v1/rules`
- The script MUST verify SLI recording rules are producing data by querying each recording rule name
- The script MUST verify GCP uptime checks, alert policies, log-based metrics, and dashboards match the repo definitions
- The script MUST verify the `auth-verify-prod` and `cert-verify-prod` CronJobs exist
- The script SHOULD verify Grafana dashboard exists and contains required panels via the Grafana API

### CI Integration

- The system MUST run `validate-observability-compliance.sh --mode local --strict` as a CI check on every PR that modifies files in `deploy/k8s/base/monitoring/` or `infrastructure/monitoring/`
- The system SHOULD run `validate-observability-compliance.sh --mode runtime` as a post-deployment check
- CI failure MUST block merge for local mode checks
- Runtime mode failures SHOULD create a GitHub issue or Slack notification but MUST NOT block deployment (to avoid circular dependency where broken monitoring prevents deploying monitoring fixes)

### Compliance Report Format

The system MUST produce a compliance report in the following structure when `--json` is used:

```json
{
  "timestamp": "<ISO8601>",
  "mode": "local|runtime|all",
  "strict": true,
  "summary": {
    "total_checks": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "warnings": 0
  },
  "categories": {
    "servicemonitors": { "required": 0, "present": 0, "missing": [] },
    "prometheusrules": { "required": 0, "present": 0, "missing": [] },
    "alert_rules": { "required": 0, "present": 0, "missing": [] },
    "recording_rules": { "required": 0, "producing_data": 0, "no_data": [] },
    "gcp_uptime_checks": { "required": 0, "present": 0, "missing": [] },
    "gcp_alert_policies": { "required": 0, "present": 0, "missing": [] },
    "gcp_log_metrics": { "required": 0, "present": 0, "missing": [] },
    "gcp_dashboards": { "required": 0, "present": 0, "missing": [] },
    "grafana_dashboards": { "required": 0, "present": 0, "missing": [] }
  },
  "checks": [
    { "name": "<check>", "ok": true, "exit_code": 0, "message": "" }
  ]
}
```

- The human-readable format MUST print `OK` or `FAIL` per check, followed by a summary line
- The report MUST be compatible with the existing `audit-observability.sh` output format for consistency

### Non-Functional Requirements

- The validation script MUST complete local mode checks in under 10 seconds
- The validation script MUST complete runtime mode checks in under 60 seconds
- The validation script MUST NOT require credentials beyond the default kubectl context and gcloud auth
- The script MUST be idempotent (running it twice produces the same result)
- The script MUST work on both developer machines (macOS, Linux) and CI runners
- The script MUST require only standard tools: `bash`, `kubectl`, `gcloud`, `jq`, `curl`
- Every check MUST have a deterministic name that can be referenced in CI skip lists

## Acceptance Criteria

### ServiceMonitor Compliance

- [ ] AC-OVR-001: Given the monitoring kustomization.yaml, when `grep servicemonitor deploy/k8s/base/monitoring/kustomization.yaml` is run, then all deployed ServiceMonitor filenames listed in the "Required ServiceMonitors" table are present
- [ ] AC-OVR-002: Given a running production cluster, when `kubectl get servicemonitor -n mereka-lms -o json` is run, then ServiceMonitors exist for at minimum: `lms-metrics`, `cms-metrics`, `mysql-metrics`, `redis-metrics`, `enterprise-catalog-metrics`, `enterprise-access-metrics`, `enterprise-subsidy-metrics`
- [ ] AC-OVR-003: Given any ServiceMonitor YAML file in `deploy/k8s/base/monitoring/`, when the file is parsed, then `spec.endpoints[0].interval` is `30s` and `spec.endpoints[0].scrapeTimeout` is <= `10s`
- [ ] AC-OVR-004: Given any ServiceMonitor YAML file, when labels are inspected, then `app.kubernetes.io/component: monitoring` is present in `metadata.labels`

### PrometheusRule Compliance

- [ ] AC-OVR-005: Given the monitoring kustomization.yaml, when the file is parsed, then all PrometheusRule filenames (`prometheusrule-lms.yaml`, `prometheusrule-enterprise.yaml`, `prometheusrule-velero.yaml`, `prometheusrule-slo.yaml`, `prometheusrule-auth.yaml`) are listed as resources
- [ ] AC-OVR-006: Given a running production cluster, when `kubectl get prometheusrule -n mereka-lms -o json` is run, then resources exist for at minimum: `lms-alerts`, `enterprise-alerts`, `velero-alerts`, `slo-recording-rules`, `auth-alerts`
- [ ] AC-OVR-007: Given any PrometheusRule YAML file, when labels are inspected, then `prometheus: kube-prometheus` is present in `metadata.labels`
- [ ] AC-OVR-008: Given the PrometheusRule `lms-alerts`, when its alert rules are extracted, then all alert names listed in the "prometheusrule-lms.yaml" table are present (22 alerts)
- [ ] AC-OVR-009: Given the PrometheusRule `enterprise-alerts`, when its alert rules are extracted, then all alert names listed in the "prometheusrule-enterprise.yaml" table are present (12 alerts)
- [ ] AC-OVR-010: Given the PrometheusRule `slo-recording-rules`, when its alert rules are extracted, then all SLO alert names are present: `SLOBudgetFastBurn`, `SLOBudgetSlowBurn`, `SLOBudgetWarning`, `SLOBudgetExhausted`, `SLOBudgetLow`, `SLIMeasurementDown`
- [ ] AC-OVR-011: Given any alert rule in any PrometheusRule, when its labels and annotations are inspected, then `severity` label and `summary` + `description` annotations are present

### SLI Recording Rule Compliance

- [ ] AC-OVR-012: Given the PrometheusRule `slo-recording-rules`, when recording rules are extracted, then rules exist for: `mereka:http_requests:availability_ratio_5m`, `mereka:http_requests:availability_ratio_30m`, `mereka:http_requests:availability_ratio_1h`, `mereka:http_requests:availability_ratio_6h` for both `lms` and `cms` services
- [ ] AC-OVR-013: Given the PrometheusRule `slo-recording-rules`, when recording rules are extracted, then rules exist for: `mereka:http_request_duration:p50_5m`, `mereka:http_request_duration:p95_5m`, `mereka:http_request_duration:p99_5m` for both `lms` and `cms` services
- [ ] AC-OVR-014: Given the PrometheusRule `slo-recording-rules`, when recording rules are extracted, then rules exist for: `mereka:slo:burn_rate_5m`, `mereka:slo:burn_rate_30m`, `mereka:slo:burn_rate_1h`, `mereka:slo:burn_rate_6h` for both `lms` and `cms` services
- [ ] AC-OVR-015: Given the PrometheusRule `slo-recording-rules`, when recording rules are extracted, then rules exist for: `mereka:slo:error_budget_remaining_ratio`, `mereka:slo:error_budget_remaining_minutes` for both `lms` and `cms` services
- [ ] AC-OVR-016: Given a running Prometheus instance with django-prometheus data, when `mereka:http_requests:availability_ratio_5m{service="lms"}` is queried, then a numeric value between 0 and 1 is returned

### GCP Monitoring Compliance

- [ ] AC-OVR-017: Given the `infrastructure/monitoring/uptime/` directory, when all JSON files are parsed, then every file is valid JSON with a `displayName` field
- [ ] AC-OVR-018: Given a running GCP project, when uptime checks are listed via `gcloud monitoring uptime list-configs`, then every `displayName` from the repo uptime directory has a matching GCP resource
- [ ] AC-OVR-019: Given the `infrastructure/monitoring/alerts/` directory, when all JSON files are parsed (excluding legacy and unsupported), then every `displayName` has a corresponding GCP alert policy
- [ ] AC-OVR-020: Given the `infrastructure/monitoring/logging-metrics/` directory, when all JSON files are parsed, then every `name` field has a corresponding GCP log-based metric
- [ ] AC-OVR-021: Given the `infrastructure/monitoring/dashboards/` directory, when all JSON files are parsed (excluding legacy), then every `displayName` has a corresponding GCP dashboard

### Grafana Dashboard Compliance

- [ ] AC-OVR-022: Given the file `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`, when parsed, then it is valid JSON with `required.panel_titles` and `required.query_fragments` arrays
- [ ] AC-OVR-023: Given a running Grafana instance, when the dashboard with UID `bbi-app-mereka-lms` is fetched via API, then all `required.panel_titles` from the contract are present as panel titles in the dashboard

### Validation Script

- [ ] AC-OVR-024: Given the file `scripts/qa/validate-observability-compliance.sh` exists, when run with `--mode local`, then it performs all local-mode checks and exits 0 when all pass
- [ ] AC-OVR-025: Given the validation script, when run with `--mode local --json`, then the output is valid JSON matching the compliance report schema defined in this spec
- [ ] AC-OVR-026: Given a deliberately broken state (e.g., ServiceMonitor file missing from kustomization.yaml), when the validation script is run with `--mode local --strict`, then it exits non-zero and the report identifies the specific missing resource
- [ ] AC-OVR-027: Given the validation script, when run with `--mode runtime`, then it queries both kubectl and gcloud for live resource verification

### CI Integration

- [ ] AC-OVR-028: Given a PR that modifies files in `deploy/k8s/base/monitoring/`, when CI runs, then the validation script executes in local mode as a required check
- [ ] AC-OVR-029: Given a PR that removes a ServiceMonitor from kustomization.yaml without adding a documented waiver, when CI runs the validation script, then the check fails and blocks merge

### Alert Rule Quality

- [ ] AC-OVR-030: Given every critical-severity alert in the cluster, when its configuration is inspected, then it has a `for` duration of <= 5 minutes (critical alerts must fire quickly)
- [ ] AC-OVR-031: Given every alert rule, when its `expr` is evaluated against the Prometheus API, then it does not produce a PromQL syntax error

## Edge Cases

### ServiceMonitor Target Missing (Pod Not Running)

**Symptom**: ServiceMonitor exists but Prometheus shows "target down" because the pod is not running or the service has no endpoints.

**Cause**: Pod crashed, deployment scaled to 0, or service selector mismatch.

**Mitigation**:
- The validation script MUST distinguish between "ServiceMonitor CRD exists" and "scrape target is healthy"
- A missing scrape target MUST NOT be treated as a ServiceMonitor compliance failure (the pod availability alert handles this)
- The compliance report SHOULD include a "target_health" section that lists scrape target status for informational purposes

### django-prometheus Not Yet Installed

**Symptom**: SLI recording rules exist in the PrometheusRule but produce `NaN` or no data because the LMS/CMS `/metrics` endpoint returns 400.

**Cause**: django-prometheus is not installed in the Open edX image (known gap documented in `IMPLEMENTATION_STATUS.md`).

**Mitigation**:
- The validation script MUST accept a `--known-gaps` file that lists expected failures (e.g., `recording_rule:mereka:http_requests:availability_ratio_5m:no_data`)
- Known gaps MUST be excluded from the failure count but MUST appear in the report as "known_gap" status
- The known gaps file MUST NOT suppress failures indefinitely -- each entry MUST have an expiry date
- When django-prometheus is deployed, the known gaps entry MUST be removed and the recording rule data check becomes a hard requirement

### GCP Auth Not Available in CI

**Symptom**: Runtime GCP checks fail because the CI runner does not have gcloud credentials.

**Cause**: CI environment does not have GCP service account configured.

**Mitigation**:
- When `gcloud auth list` returns no active account, runtime GCP checks MUST be skipped with status "skipped" (not "failed")
- In strict mode, the script MUST still exit 0 for skipped checks (only failures cause non-zero exit)
- The compliance report MUST clearly indicate which checks were skipped and why

### Alert Rule PromQL Depends on Absent Metrics

**Symptom**: An alert rule references a metric that does not exist yet (e.g., `caddy_http_requests_total` before Caddy metrics are enabled).

**Cause**: The alert rule is deployed before the ServiceMonitor or the service's metrics endpoint is configured.

**Mitigation**:
- Alert rules referencing absent metrics MUST NOT fire false alerts (PromQL with absent metrics evaluates to empty, which is safe for most expressions)
- The validation script SHOULD check for alert rules whose `expr` references metrics not present in any ServiceMonitor's known metric set
- The compliance report SHOULD include a "dangling_alerts" section listing alerts whose source metrics are not being scraped

### Kustomization Drift from YAML Files

**Symptom**: A new ServiceMonitor YAML file exists in `deploy/k8s/base/monitoring/` but is not listed in `kustomization.yaml`, so it is not applied to the cluster.

**Cause**: Developer created the file but forgot to add it to kustomization.yaml.

**Mitigation**:
- The validation script MUST compare the list of `servicemonitor-*.yaml` and `prometheusrule-*.yaml` files on disk against the resources listed in `kustomization.yaml`
- Any YAML file on disk not listed in kustomization.yaml MUST be flagged as a failure
- Any resource listed in kustomization.yaml without a corresponding file on disk MUST be flagged as a failure

### Partial PrometheusRule Update

**Symptom**: A PrometheusRule is updated to add new alerts, but the old alerts are accidentally removed.

**Cause**: Full file replacement instead of additive edit.

**Mitigation**:
- The validation script MUST maintain a "required alert names" list per PrometheusRule (defined in this spec)
- The script MUST verify that all required alert names are present in the deployed PrometheusRule
- A missing alert name MUST be a hard failure, even if other alerts exist

### Rate Limiting on GCP API Calls

**Symptom**: Runtime validation fails with GCP API quota errors when run frequently.

**Cause**: Multiple CI runs or manual audits hitting the GCP Monitoring API.

**Mitigation**:
- The validation script SHOULD cache GCP API responses for 5 minutes using a temporary file
- The script SHOULD use `--format=json` with gcloud to minimize API calls (single list call per resource type)
- Runtime validation SHOULD NOT run more than once per hour in CI

## Observability

### Logs

- Validation script runs MUST be logged with structured output: `{event: "observability_compliance_check", mode: "<mode>", strict: <bool>, total: <N>, passed: <N>, failed: <N>, duration_ms: <N>}`
- Each individual check result MUST be logged: `{event: "compliance_check_result", name: "<check>", ok: <bool>, message: "<msg>"}`

### Metrics

| Metric | Type | Labels | Source |
|--------|------|--------|--------|
| `mereka_observability_compliance_score` | Gauge | `mode` (local, runtime) | Validation script (push to Prometheus Pushgateway or expose via file) |
| `mereka_observability_checks_total` | Counter | `result` (pass, fail, skip) | Validation script |
| `mereka_observability_servicemonitors_required` | Gauge | - | Validation script |
| `mereka_observability_servicemonitors_present` | Gauge | - | Validation script |
| `mereka_observability_alerts_required` | Gauge | - | Validation script |
| `mereka_observability_alerts_present` | Gauge | - | Validation script |

### Alerts

| Alert Name | Severity | Condition | Routing |
|------------|----------|-----------|---------|
| `ObservabilityComplianceDegraded` | warning | `mereka_observability_compliance_score{mode="runtime"} < 1.0` for 1 hour | Slack `#ops-warnings` |
| `ObservabilityComplianceCritical` | critical | `mereka_observability_compliance_score{mode="runtime"} < 0.8` for 30 minutes | Slack `#ops-alerts` + page on-call |
| `ServiceMonitorMissing` | warning | `mereka_observability_servicemonitors_present < mereka_observability_servicemonitors_required` for 1 hour | Slack `#ops-warnings` |

### Dashboards

- The Grafana dashboard `bbi-app-mereka-lms` SHOULD include a "Monitoring Health" row with panels for:
  - Compliance score gauge (0-100%)
  - ServiceMonitor coverage (present vs required)
  - Alert rule coverage (present vs required)
  - Recording rule data availability

## Rollout & Rollback

### Rollout Plan

**Phase 1 -- Validation Script (Week 1)**

1. Create `scripts/qa/validate-observability-compliance.sh` with local mode checks
2. Verify it correctly reports current state: deployed ServiceMonitors pass, missing ones fail
3. Create `known-gaps.yml` documenting django-prometheus dependency
4. Run against the repository and confirm expected output
5. Gate: Script runs, produces valid JSON, and correctly identifies known gaps

**Phase 2 -- Fill ServiceMonitor Gaps (Week 2-3)**

1. Create `servicemonitor-caddy.yaml` for Caddy metrics (port 2019)
2. Create `servicemonitor-forum.yaml`, `servicemonitor-discovery.yaml`, `servicemonitor-ecommerce.yaml`, `servicemonitor-credentials.yaml`, `servicemonitor-mfe.yaml`
3. Create `servicemonitor-purchase-gateway.yaml` when Purchase Gateway is deployed
4. Add all new ServiceMonitors to kustomization.yaml
5. Apply to cluster and verify Prometheus discovers targets
6. Gate: All required ServiceMonitors exist and are listed in kustomization.yaml; validation script local mode passes

**Phase 3 -- Fill Alert Gaps (Week 3-4)**

1. Create `prometheusrule-caddy.yaml` with Caddy-specific alerts
2. Create `prometheusrule-services.yaml` with pod-down alerts for Tier 2/3 services
3. Add latency regression and error rate spike alerts to `prometheusrule-slo.yaml`
4. Add all new PrometheusRules to kustomization.yaml
5. Apply to cluster and verify alerts load in Prometheus
6. Gate: All required alert rules exist; validation script local mode passes with zero failures

**Phase 4 -- Runtime Validation (Week 4-5)**

1. Add runtime mode checks to the validation script (kubectl, gcloud, Grafana API)
2. Test runtime mode against the production cluster
3. Fix any runtime-only discrepancies (GCP resources out of sync)
4. Gate: Validation script runtime mode passes with zero failures (excluding known gaps)

**Phase 5 -- CI Integration (Week 5-6)**

1. Add GitHub Actions workflow step running `validate-observability-compliance.sh --mode local --strict`
2. Configure the step to trigger on changes to `deploy/k8s/base/monitoring/**` and `infrastructure/monitoring/**`
3. Add post-deployment runtime check as a non-blocking notification
4. Gate: CI blocks PRs that break observability compliance; post-deploy check sends Slack notification on drift

### Feature Flags

- `OBSERVABILITY_COMPLIANCE_CI_GATE` (GitHub Actions repo variable): When `true`, the compliance check is a required CI step. Default: `false` during Phase 1-3, `true` from Phase 5.
- `OBSERVABILITY_COMPLIANCE_STRICT` (environment variable): When `1`, known gaps are treated as failures. Default: `0` until django-prometheus is deployed.
- `OBSERVABILITY_COMPLIANCE_KNOWN_GAPS` (file path): Path to the known gaps YAML file. Default: `deploy/k8s/base/monitoring/known-gaps.yml`.

### Backward Compatibility

- This spec adds new resources (ServiceMonitors, PrometheusRules, scripts) and does not modify existing ones
- Existing `audit-observability.sh`, `audit-grafana-dashboard.sh`, and `audit-db-exporter-telemetry.sh` continue to work independently
- The new validation script is additive and does not replace the existing audit scripts
- Existing CI workflows are not modified until Phase 5 (feature flag controlled)

### Rollback Steps

1. **Phase 1**: Delete `scripts/qa/validate-observability-compliance.sh`. No operational impact.
2. **Phase 2**: Delete new ServiceMonitor YAML files and remove from kustomization.yaml. Apply to cluster. Prometheus stops scraping the removed targets. Existing ServiceMonitors unaffected.
3. **Phase 3**: Delete new PrometheusRule YAML files and remove from kustomization.yaml. Apply to cluster. New alerts stop firing. Existing alerts unaffected.
4. **Phase 4**: Runtime mode is script logic only -- no cluster state to roll back.
5. **Phase 5**: Set `OBSERVABILITY_COMPLIANCE_CI_GATE=false` in GitHub Actions. CI check stops running. Remove the workflow step if desired.

## Decisions Made (2026-02-13)

1. **✅ Caddy metrics port**: Should be enabled (port :2019), but needs verification. **Action**: Check production Caddy config before creating ServiceMonitor.

2. **✅ MFE monitoring approach**: Monitor MFEs via platform-independent uptime checks (NOT GCP-only)
   - **Rationale**: Avoid vendor lock-in, enable monitoring of dev/staging clusters not on GCP
   - **Implementation**: Use Prometheus Blackbox Exporter for HTTP probes (cluster-agnostic)
   - ServiceMonitor targets Blackbox Exporter, which probes MFE URLs

3. **✅ Forum metrics**: Forum exposes **separate /metrics endpoint** - create dedicated ServiceMonitor

4. **✅ Known gaps file format**: Use **YAML** for consistency with other spec tooling

## Open Questions (Remaining)

5. **Purchase Gateway readiness**: When will Purchase Gateway be deployed to production and ready for ServiceMonitor?

6. **Grafana API access from CI**: Does CI runner have network access to `grafana.mereka.io`? If not, skip Grafana dashboard checks in CI.

7. **Compliance score metric push**: Should validation script push metrics to Prometheus Pushgateway, write to textfile collector, or use log-based extraction?

8. **Alert decommissioning process**: When services are decommissioned, how to remove alerts from this spec? Need "deprecated alerts" section with removal dates?
