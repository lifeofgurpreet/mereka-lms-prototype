---
spec: slo-sla-service-level-management_spec.md
status: draft
last_updated: '2026-03-09'
---

# SLO/SLA Service Level Management - Implementation Plan

**Source Spec**: `specs/slo-sla-service-level-management_spec.md`

**Status**: Draft

**Owner**: engineering

**Last Updated**: 2026-02-10

---

## Summary

This plan converts the SLO/SLA spec's 23 acceptance criteriainto actionable implementation tasks. The spec defines Service Level Indicators (SLIs), Service Level Objectives (SLOs), Service Level Agreements (SLAs), error budget tracking, deployment gating, performance regression detection, maintenance windows, incident communication, on-call rotation, and monthly/quarterly reporting for Mereka Academy Open edX on GKE.

**Total Acceptance Criteria**: 23 (AC-001 through AC-023)

**Estimated Timeline**: 9-12 weeks across 5 phases

**Prerequisites Verified**:
- Prometheus (kube-prometheus-stack) is deployed in `monitoring` namespace ✓
- GCP uptime checks exist for public endpoints ✓
- Grafana is accessible at `grafana.mereka.io` ✓
- ServiceMonitors exist for LMS, CMS, MySQL, Redis ✓
- django-prometheus is integrated (needs image rebuild) ⚠️
- Alertmanager is configured with Slack notifications ✓

---

## Implementation Tasks

### Phase 1 — SLI Foundation (Week 1-2)

#### Build

- [ ] **[M]** Verify django-prometheus metrics endpoint (`deploy/k8s/base/monitoring/README.md`) | AC: #3 | Depends: None
  - **Done**: `kubectl exec -n mereka-lms deploy/lms -- curl-s localhost:8000/metrics | grep http_request_duration_seconds` returns histogram buckets
  - **Files**: `infrastructure/tutor/custom-apps/openedx_prometheus/`
  - **Action**: If missing, rebuild Open edX image with django-prometheus integration

- [ ] **[M]** Create Prometheus recording rules for availability ratio (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | AC: #4, #5 | Depends: None
  - **Done**: Recording rules `mereka:http_requests:availability_ratio_5m` and `mereka:http_requests:availability_ratio_30d` return values between 0 and 1
  - **Files**: New file `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
  - **Metrics**:
    - `mereka:http_requests:availability_ratio_5m`
    - `mereka:http_requests:availability_ratio_30d`
    - `mereka:http_request_duration:p50_5m`
    - `mereka:http_request_duration:p95_5m`
    - `mereka:http_request_duration:p99_5m`

- [ ] **[L]** Implement Caddy metrics exporter for reverse proxy latency (`deploy/k8s/base/apps/caddy/`) | AC: #3 | Depends: None
  - **Done**: Caddy exposes request duration metrics on `/metrics` endpoint
  - **Files**:
    - `deploy/k8s/base/apps/caddy/Caddyfile` (add metrics plugin)
    - `deploy/k8s/base/services.yml` (add metrics port)
    - `deploy/k8s/base/monitoring/servicemonitor-caddy.yaml`(new ServiceMonitor)

- [ ] **[S]** Document service tier classification (`docs/operations/SERVICE_TIERS.md`) | AC: #1 | Depends: None
  - **Done**: Tier 1/2/3 service mapping matches spec table
  - **Files**: New file `docs/operations/SERVICE_TIERS.md`

- [ ] **[M]** Verify GCP uptime checks exist for all Tier 1/2endpoints (`infrastructure/monitoring/uptime/`) | AC: #6 | Depends: None
  - **Done**: `gcloud monitoring uptime list-configs --project=mereka-lms` shows checks for LMS, Studio, MFE, Caddy, MySQL, Redis
  - **Files**: `infrastructure/monitoring/uptime/*.json`

#### Test

- [ ] **[M]** Create recording rule validation script (`scripts/qa/verify-slo-recording-rules.sh`) | AC: #5 | Depends: Recording rules
  - **Done**: Script queries each recording rule and verifiesnon-empty results
  - **Files**: New file `scripts/qa/verify-slo-recording-rules.sh`

- [ ] **[S]** Add service tier test (`scripts/qa/test-service-tier-mapping.sh`) | AC: #1 | Depends: Service tier doc
  - **Done**: Script verifies every deployment maps to exactly one tier
  - **Files**: New file `scripts/qa/test-service-tier-mapping.sh`

#### Observability

- [ ] **[S]** Add SLI data collection failure alert (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | Req: OBS-1 |Depends: Recording rules
  - **Done**: Alert fires if any Tier 1 service has no SLI data for 10 minutes
  - **Condition**: `up{job=~"lms-metrics|cms-metrics|caddy-metrics", namespace="mereka-lms"} == 0`

#### Docs

- [ ] **[S]** Document SLI measurement methodology (`docs/operations/SLI_MEASUREMENT.md`) | Depends: Recording rules
  - **Done**: Explains availability calculation, latency percentiles, error rate, exclusion rules
  - **Files**: New file `docs/operations/SLI_MEASUREMENT.md`

#### Rollout

- [ ] **[S]** Set feature flag `STRICT_SLO_MEASUREMENT=0` during Phase 1 | Depends: None
  - **Done**: Environment variable set in CI/CD pipeline
  - **Files**: GitHub Actions workflow variables

---

### Phase 2 — Error Budget and Dashboard (Week 3-4)

#### Build

- [ ] **[L]** Create error budget recording rules (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | AC: #7 | Depends: Availability recording rules
  - **Done**: Recording rules for `mereka_slo_error_budget_remaining_ratio`, `mereka_slo_error_budget_remaining_minutes`,burn rate (1h, 6h) return valid data
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
  - **Metrics**:
    - `mereka_slo_error_budget_remaining_ratio`
    - `mereka_slo_error_budget_remaining_minutes`
    - `mereka_slo_burn_rate_1h`
    - `mereka_slo_burn_rate_6h`

- [ ] **[L]** Create "Mereka LMS - SLO Overview" Grafana dashboard (`infrastructure/monitoring/dashboards/slo-overview.json`) | AC: #8 | Depends: Error budget recording rules
  - **Done**: Dashboard loads within 5 seconds and shows: per-service availability, error budget remaining, burn rate trend, latency distributions
  - **Files**: New file `infrastructure/monitoring/dashboards/slo-overview.json`
  - **Panels**:
    - Availability ratio per service (30-day rolling)
    - Error budget remaining (bar chart)
    - Burn rate trend (time series)
    - Latency percentiles by endpoint category
    - Deployment annotations
    - Maintenance window markers

- [ ] **[M]** Create "Mereka LMS - SLO Detail" per-service dashboards (`infrastructure/monitoring/dashboards/slo-detail-*.json`) | AC: #8 | Depends: Error budget recording rules
  - **Done**: Individual service deep-dive dashboards for LMS, CMS, MFE, Caddy
  - **Files**: New files `infrastructure/monitoring/dashboards/slo-detail-{lms,cms,mfe,caddy}.json`

- [ ] **[M]** Create "Mereka LMS - Error Budget" dashboard (`infrastructure/monitoring/dashboards/error-budget.json`) | AC: #8 | Depends: Error budget recording rules
  - **Done**: Budget remaining per tier, consumption timeline, deployment freeze status, budget forecast
  - **Files**: New file `infrastructure/monitoring/dashboards/error-budget.json`

- [ ] **[M]** Create burn rate alert rules (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | AC: #9 | Depends: Burnrate recording rules
  - **Done**: Alerts `SLOBudgetFastBurn`, `SLOBudgetSlowBurn`, `SLOBudgetWarning`, `SLOBudgetExhausted`, `SLOBudgetLow` are defined
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
  - **Alerts**:
    - `SLOBudgetFastBurn` (P1): 1h burn rate > 14.4x AND 5m burn rate > 14.4x
    - `SLOBudgetSlowBurn` (P2): 6h burn rate > 6x AND 30m burn rate > 6x
    - `SLOBudgetWarning` (P3): 6h burn rate > 3x
    - `SLOBudgetExhausted` (P1): Error budget remaining < 0%
    - `SLOBudgetLow` (P2): Error budget remaining < 25%

#### Test

- [ ] **[M]** Create error budget calculation test (`scripts/qa/test-error-budget-calculation.py`) | AC: #7 | Depends: Error budget recording rules
  - **Done**: Script verifies error budget formula matches spec for sample data
  - **Files**: New file `scripts/qa/test-error-budget-calculation.py`

- [ ] **[M]** Simulate error injection to test burn rate alerts (`scripts/qa/simulate-error-injection.sh`) | AC: #9 | Depends: Burn rate alerts
  - **Done**: Script injects errors into test endpoint and verifies alert fires within 5 minutes
  - **Files**: New file `scripts/qa/simulate-error-injection.sh`

- [ ] **[S]** Test dashboard load performance (`scripts/qa/test-dashboard-load-time.sh`) | NFR: Performance | Depends: Grafana dashboards
  - **Done**: Script verifies SLO Overview dashboard loads within 5 seconds
  - **Files**: New file `scripts/qa/test-dashboard-load-time.sh`

#### Observability

- [ ] **[S]** Add log entry for error budget threshold crossings | Req: OBS-1 | Depends: Burn rate alerts
  - **Done**: Structured log events: `{event: "slo_budget_threshold_crossed", service: "<name>", tier: "<tier>", remaining_pct: <N>, threshold: "<level>"}`
  - **Files**: Update Alertmanager templates in `deploy/k8s/base/monitoring/`

#### Docs

- [ ] **[S]** Document error budget policy (`docs/operations/ERROR_BUDGET_POLICY.md`) | Depends: Error budget recording rules
  - **Done**: Explains error budget calculation, burn rate thresholds, deployment gating tiers
  - **Files**: New file `docs/operations/ERROR_BUDGET_POLICY.md`

#### Rollout

- [ ] **[S]** Enable burn rate alerts in Slack (`deploy/k8s/base/monitoring/alertmanager-config.yaml`) | Depends: Burn rate alerts
  - **Done**: `SLO_ALERT_ROUTING` set to Slack-only during Phase 2
  - **Files**: `deploy/k8s/base/monitoring/alertmanager-config.yaml`

---

### Phase 3 — Deployment Gating (Week 5-6)

#### Build

- [ ] **[L]** Create deployment gate check script (`scripts/qa/check-error-budget-gate.sh`) | AC: #10, #11 | Depends: Error budget metrics
  - **Done**: Script queries `mereka_slo_error_budget_remaining_ratio` and returns exit code based on deployment policy table
  - **Files**: New file `scripts/qa/check-error-budget-gate.sh`
  - **Exit codes**:
    - 0: >= 50% (deploy freely)
    - 1: 25-49% (needs engineering lead approval)
    - 2: 10-24% (needs engineering lead + product approval)
    - 3: < 10% (needs VP/CTO approval)

- [ ] **[M]** Integrate gate check into GitHub Actions workflow (`.github/workflows/deploy-production.yml`) | AC: #10, #11| Depends: Gate check script
  - **Done**: CI/CD pipeline step runs gate check before production deploy, blocks on exit code > 0 without manual approval
  - **Files**: `.github/workflows/deploy-production.yml`

- [ ] **[M]** Implement deployment gate override mechanism (`scripts/qa/check-error-budget-gate.sh`) | AC: #12 | Depends:Gate check script
  - **Done**: Gate check accepts `--override` flag with `--approver`, `--justification` parameters; logs override to structured log
  - **Files**: `scripts/qa/check-error-budget-gate.sh`

- [ ] **[S]** Create deployment gate log table (`docs/operations/DEPLOYMENT_GATE_LOG.md`) | AC: #12 | Depends: Override mechanism
  - **Done**: Template for logging: approver, timestamp, justification, deployment identifier
  - **Files**: New file `docs/operations/DEPLOYMENT_GATE_LOG.md`

#### Test

- [ ] **[L]** Test gate behavior at each budget threshold (`scripts/qa/test-deployment-gate-thresholds.sh`) | AC: #10, #11| Depends: Gate check script
  - **Done**: Script tests gate at >= 50%, 25-49%, 10-24%, <10% error budget levels
  - **Files**: New file `scripts/qa/test-deployment-gate-thresholds.sh`

- [ ] **[M]** Test override audit logging (`scripts/qa/test-deployment-gate-override-logging.sh`) | AC: #12 | Depends: Override mechanism
  - **Done**: Script verifies override log contains all required fields
  - **Files**: New file `scripts/qa/test-deployment-gate-override-logging.sh`

#### Observability

- [ ] **[S]** Add deployment gate decision logging | Req: OBS-1 | Depends: Gate check script
  - **Done**: Structured log: `{event: "deployment_gate_decision", service: "<name>", budget_remaining_pct: <N>, decision:"allow|block|override", approver: "<name>"}`
  - **Files**: `scripts/qa/check-error-budget-gate.sh`

- [ ] **[S]** Create `mereka_deployment_gate_decisions_total`metric (`scripts/qa/check-error-budget-gate.sh`) | Req: Metrics | Depends: Gate check script
  - **Done**: Counter metric tracks gate decisions by type (allow, block, override)
  - **Files**: `scripts/qa/check-error-budget-gate.sh` (pushto Pushgateway or log metric)

#### Docs

- [ ] **[M]** Document deployment gating policy (`docs/operations/DEPLOYMENT_GATING.md`) | Depends: Gate check script
  - **Done**: Explains deployment policy table, approval requirements, override process
  - **Files**: New file `docs/operations/DEPLOYMENT_GATING.md`

#### Rollout

- [ ] **[S]** Set feature flag `ENABLE_DEPLOYMENT_GATING=true` in GitHub Actions | Depends: CI integration
  - **Done**: Environment variable enables gate check in production deploys
  - **Files**: GitHub Actions repo variables

---

### Phase 4 — Performance Regression Detection (Week 7-8)

#### Build

- [ ] **[M]** Create 7-day rolling baseline recording rules (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | AC: #| Depends: Latency recording rules
  - **Done**: Recording rules for 7-day p95 baseline, 7-day error rate baseline, 7-day throughput baseline
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
  - **Metrics**:
    - `mereka:http_request_duration:p95_7d_baseline`
    - `mereka:http_requests:error_rate_7d_baseline`
    - `mereka:http_requests:throughput_7d_baseline`

- [ ] **[M]** Create regression detection alert rules (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) | AC: #13 | Depends: Baseline recording rules
  - **Done**: Alerts `LatencyRegressionSpike`, `LatencyRegressionDrift`, `ErrorRateSpike` fire when thresholds exceeded
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
  - **Alerts**:
    - `LatencyRegressionSpike` (P2): p95 > 2x 7-day baselinefor 15 min
    - `LatencyRegressionDrift` (P3): p95 > 1.5x 7-day baseline for 1 hour
    - `ErrorRateSpike` (P1): 5xx rate > 3x 7-day average formin

- [ ] **[L]** Add deployment event annotations to Grafana dashboards (`infrastructure/monitoring/dashboards/slo-overview.json`) | AC: #14, #15 | Depends: SLO Overview dashboard
  - **Done**: Vertical markers appear on latency/availabilitypanels at each deployment timestamp; annotations include commit SHA
  - **Files**:
    - `infrastructure/monitoring/dashboards/slo-overview.json`
    - `infrastructure/monitoring/dashboards/slo-detail-*.json`
  - **Implementation**: Use Grafana Annotations API or external annotation source

- [ ] **[M]** Correlate regression alerts with deployment events (`deploy/k8s/base/monitoring/prometheusrule-slo.yaml`) |AC: #14 | Depends: Regression alerts
  - **Done**: Alert annotation includes deployment identifierif regression detected within 30 minutes of deploy
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`

#### Test

- [ ] **[M]** Test regression detection with artificial latency (`scripts/qa/test-latency-regression-detection.sh`) | AC:#13 | Depends: Regression alerts
  - **Done**: Script introduces artificial latency in test endpoint and verifies alert fires within 15 minutes
  - **Files**: New file `scripts/qa/test-latency-regression-detection.sh`

- [ ] **[S]** Verify deployment annotations appear on dashboard (`scripts/qa/test-deployment-annotations.sh`) | AC: #15 |Depends: Dashboard annotations
  - **Done**: Script triggers test deployment and verifies annotation appears on Grafana
  - **Files**: New file `scripts/qa/test-deployment-annotations.sh`

#### Observability

- [ ] **[S]** Retain performance baseline data for 90 days |Req: NFR (Reliability) | Depends: Baseline recording rules
  - **Done**: Prometheus retention extended to 90 days OR long-term storage (Thanos/GCS) configured
  - **Files**: Prometheus configuration in `monitoring` namespace

#### Docs

- [ ] **[S]** Document performance regression policy (`docs/operations/PERFORMANCE_REGRESSION_POLICY.md`) | Depends: Regression alerts
  - **Done**: Explains regression thresholds, correlation with deployments, rollback triggers
  - **Files**: New file `docs/operations/PERFORMANCE_REGRESSION_POLICY.md`

#### Rollout

- [ ] **[S]** Enable page-capable alert routing for regression alerts | Depends: Regression alerts
  - **Done**: `SLO_ALERT_ROUTING` updated to page on-call forP1/P2 regression alerts
  - **Files**: `deploy/k8s/base/monitoring/alertmanager-config.yaml`

---

### Phase 5 — Process and Reporting (Week 9-12)

#### Build

- [ ] **[M]** Create monthly SLA report generation script (`scripts/qa/generate-sla-report.sh`) | AC: #22 | Depends: All SLI metrics
  - **Done**: Script queries Prometheus and generates reportwith: per-service availability, latency percentiles, error budget status, incident summary, maintenance log
  - **Files**: New file `scripts/qa/generate-sla-report.sh`
  - **Output**: Markdown or PDF report in `var/reports/sla/YYYY-MM.md`

- [ ] **[M]** Create quarterly SLA report generation script (`scripts/qa/generate-quarterly-sla-report.sh`) | Req: Reporting | Depends: Monthly script
  - **Done**: Script generates quarterly report with: 90-daytrends, capacity planning, on-call health
  - **Files**: New file `scripts/qa/generate-quarterly-sla-report.sh`

- [ ] **[S]** Sanitize reports for client distribution (`scripts/qa/sanitize-sla-report.sh`) | AC: #23 | Depends: Report scripts
  - **Done**: Script removes internal IP addresses, secret names, internal hostnames from reports
  - **Files**: New file `scripts/qa/sanitize-sla-report.sh`

- [ ] **[S]** Create maintenance window calendar (`docs/operations/MAINTENANCE_CALENDAR.md`) | AC: #16, #17 | Depends: None
  - **Done**: Template for recording maintenance windows withadvance notice tracking
  - **Files**: New file `docs/operations/MAINTENANCE_CALENDAR.md`

- [ ] **[M]** Implement maintenance window exclusion logic (`scripts/qa/generate-sla-report.sh`) | AC: #16 | Depends: Maintenance calendar
  - **Done**: Report script excludes declared maintenance window duration from availability calculations
  - **Files**: `scripts/qa/generate-sla-report.sh`

#### Test

- [ ] **[M]** Generate first monthly SLA report from production data (`scripts/qa/generate-sla-report.sh`) | AC: #22 | Depends: Report script
  - **Done**: Report generated successfully, reviewed by engineering, and validated against raw metrics
  - **Files**: `var/reports/sla/YYYY-MM.md`

- [ ] **[S]** Test report sanitization (`scripts/qa/test-report-sanitization.sh`) | AC: #23 | Depends: Sanitization script
  - **Done**: Script verifies no internal IP addresses, secret names, hostnames in sanitized report
  - **Files**: New file `scripts/qa/test-report-sanitization.sh`

#### Observability

- [ ] **[S]** Add maintenance window lifecycle logging | Req:OBS-1 | Depends: Maintenance calendar
  - **Done**: Structured logs: `{event: "maintenance_window",action: "declared|started|ended|overrun", start: "<ISO8601>", end: "<ISO8601>", scope: "<description>"}`
  - **Files**: Manual logging process or automated via maintenance window management tool

- [ ] **[S]** Track maintenance window overruns with alert |Edge case | Depends: Maintenance calendar
  - **Done**: Alert fires when maintenance reaches 75% of declared duration (3 hours)
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`

#### Docs

- [ ] **[L]** Document on-call rotation and escalation matrix(`docs/policies/operations/ONCALL_ROTATION.md`) | AC: #20, #21 | Depends: None
  - **Done**: Documents primary/secondary rotation, escalation tiers, response time commitments
  - **Files**: Update `docs/policies/operations/ONCALL_ROTATION.md`

- [ ] **[M]** Document incident communication SLA (`docs/operations/INCIDENT_COMMUNICATION_SLA.md`) | AC: #18, #19 | Depends: None
  - **Done**: Documents severity classification, response times, update cadence, postmortem requirements
  - **Files**: New file `docs/operations/INCIDENT_COMMUNICATION_SLA.md`

- [ ] **[M]** Create incident communication templates (`docs/operations/templates/`) | AC: #19 | Depends: Incident communication SLA
  - **Done**: Templates for: incident declaration, status update, resolution, postmortem
  - **Files**: New files in `docs/operations/templates/`

- [ ] **[S]** Document maintenance window policies (`docs/operations/MAINTENANCE_POLICIES.md`) | AC: #16, #17 | Depends: Maintenance calendar
  - **Done**: Documents advance notice, preferred windows, duration limits, notification channels
  - **Files**: New file `docs/operations/MAINTENANCE_POLICIES.md`

#### Rollout

- [ ] **[M]** Set up automated monthly report distribution (`scripts/qa/generate-sla-report.sh`) | Depends: Report script
  - **Done**: Cron job or GitHub Actions workflow generates and distributes report within 5 business days of month end
  - **Files**: `.github/workflows/monthly-sla-report.yml`

- [ ] **[S]** Distribute first report to enterprise accountsfor feedback | AC: #22 | Depends: Report generation
  - **Done**: Report sent to enterprise account contacts viaemail or secure portal
  - **Files**: N/A (process step)

- [ ] **[S]** Set `STRICT_SLO_MEASUREMENT=1` after Phase 2 completion | Depends: Phase 2 gate
  - **Done**: Environment variable enables strict measurementmode (fail on missing data)
  - **Files**: GitHub Actions workflow variables

---

## Cross-Cutting Concerns

### Test Coverage

- [ ] **[M]** Integrate SLO verification into `agent-verify`(`scripts/qa/run-operations-gates.sh`) | Depends: Phase 2 completion
  - **Done**: `agent-verify` runs SLO recording rule checks and dashboard verification
  - **Files**: `scripts/qa/run-operations-gates.sh`

### Documentation

- [ ] **[M]** Update `docs/reference/operations/MONITORING.md` with SLO/SLA references | Depends: All docs
  - **Done**: Central monitoring doc links to all SLO/SLA docs
  - **Files**: `docs/reference/operations/MONITORING.md`

- [ ] **[S]** Add SLO/SLA section to onboarding docs (`docs/onboarding/DEVELOPER_ONBOARDING.md`) | Depends: All docs
  - **Done**: New developers understand SLO measurement and error budget policy
  - **Files**: `docs/onboarding/DEVELOPER_ONBOARDING.md`

### Rollback Plan

Each phase has a rollback plan:

1. **Phase 1**: Delete `prometheusrule-slo.yaml` recording rules → No impact on existing monitoring
2. **Phase 2**: Delete SLO dashboards in Grafana; delete burnrate alerts → Error budget metrics disappear but no operational impact
3. **Phase 3**: Set `ENABLE_DEPLOYMENT_GATING=false` → Deployments proceed without gate check
4. **Phase 4**: Delete regression detection rules; remove deployment annotations → No operational impact
5. **Phase 5**: Process changes are documented, not deployedinfrastructure → Rollback is ceasing new reporting cadence

---

## Dependencies

### External

- **Prometheus**: kube-prometheus-stack in `monitoring` namespace
- **Grafana**: Accessible at `grafana.mereka.io` with datasources configured
- **GCP Monitoring**: Uptime checks and log-based metrics
- **GitHub Actions**: CI/CD pipeline for automation
- **Alertmanager**: Slack notification channels configured

### Internal

- **django-prometheus**: Must be integrated (rebuild Open edXimage if missing)
- **Caddy metrics**: Requires Caddy metrics plugin configuration
- **Incident tracking**: Manual process or integration with PagerDuty/Opsgenie (future)

---

## Acceptance

This plan is complete when:

- [ ] All 23 acceptance criteria are verified (see testmap)
- [ ] All recording rules, dashboards, alerts are deployed
- [ ] Deployment gating is enabled in CI/CD
- [ ] First monthly SLA report is generated and distributed
- [ ] On-call rotation and escalation matrix are documented
- [ ] All phase gates are passed

---

## Open Questions (From Spec)

1. **Enterprise SLA contractual numbers**: Proposed 99.9% (Tier 1), 99.5% (Tier 2), 99.0% (Tier 3) — need validation withsales/legal
2. **Financial penalties for SLA breach**: Determines how conservative SLA safety margin needs to be
3. **django-prometheus installation status**: Verify production deployment status before Phase 1
4. **Caddy access log metrics**: Verify Caddy exports requestduration to Prometheus
5. **PagerDuty adoption**: Budget/willingness for dedicated on-call tool? (Currently Slack-only)
6. **On-call team size**: 2-4 engineers → weekly rotation maybe aggressive
7. **Thanos or long-term storage**: Needed for 90-day trend analysis beyond 30-day Prometheus retention
8. **Client portal for SLA reports**: Email vs. authenticatedweb dashboard?
9. **Composite SLI adoption**: Use availability AND latency,or simpler HTTP-only availability?
10. **Existing Caddy metrics port**: Verify Caddy ServiceMonitor exists or needs creation
11. **Alert routing for SLO breaches**: Separate high-priority channel for SLO/SLA alerts?
12. **Monthly reporting start date**: Immediately after Phase2, or wait for Phase 5 completion?

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-023) hasat least one build task
- [x] Test tasks cover both happy path and edge cases
- [x] File paths specified for each task
- [x] Dependencies identified
- [x] Complexity estimated (S/M/L) for each task
- [x] Observability requirements addressed
- [x] Rollout plan defined with feature flags
- [x] Rollback steps documented per phase
- [x] Open questions captured from spec

---

**Next Steps**:

1. Review and approve this plan
2. Address open questions (particularly django-prometheus andCaddy metrics status)
3. Create implementation issues/beads for each phase
4. Begin Phase 1 implementation
5. Generate testmap YAML for automated verification
