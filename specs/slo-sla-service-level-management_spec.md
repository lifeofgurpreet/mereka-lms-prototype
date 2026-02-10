---
title: "SLO/SLA Definitions & Service Level Management"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/operations/SLO_DASHBOARDS_SETUP.md"
    - "docs/operations/MONITORING.md"
    - "docs/operations/ALERT_SEVERITY_MATRIX.md"
    - "docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/operations/OBSERVABILITY_OWNERSHIP.md"
    - "docs/operations/OBSERVABILITY_ENHANCEMENT_PLAN.md"
    - "docs/operations/DEPLOYMENT_RUNBOOK.md"
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/operations/DISASTER_RECOVERY.md"
  related_specs:
    - "specs/observability-stack_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
---

# Human Summary

## What we're building

A formal Service Level Management framework for Mereka Academy (Open edX on GKE) that defines Service Level Indicators (SLIs), Service Level Objectives (SLOs), and Service Level Agreements (SLAs) across all platform services. This spec codifies how we measure reliability (SLIs), what targets we commit to internally (SLOs), and what guarantees we offer enterprise clients contractually (SLAs). It introduces error budget accounting, deployment gating based on error budget consumption, performance regression detection, maintenance window policies, incident communication commitments, on-call escalation procedures, and monthly/quarterly reporting.

## Why it matters

Enterprise clients purchasing Mereka Academy require contractual availability and performance guarantees before signing. Today the observability stack (Prometheus, Loki, GCP Monitoring, Grafana) is operational with comprehensive alerting, but there are no formally defined SLO targets, no error budget tracking, and no mechanism to gate deployments when the platform is burning through its reliability budget. Without this framework: (a) enterprise sales cannot offer SLA guarantees, (b) deployments happen regardless of platform health, (c) performance regressions go undetected until user-visible, (d) incident response lacks contractual response time commitments, and (e) there is no structured reporting for client trust. The observability-stack spec (open question #7) explicitly asks "Should we implement SLI/SLO dashboards?" -- this spec answers that question definitively.

## Success looks like

- Every production service has a defined SLI, SLO target, and measurement methodology documented and enforced
- Error budgets are computed monthly and visible on a dashboard, with automated alerts when budgets are at risk
- Deployments to production are gated: if error budget is consumed below a defined threshold, deployment requires explicit approval
- Enterprise clients receive a monthly SLA compliance report generated from automated measurement infrastructure
- Performance regressions are detected within 15 minutes and trigger automated alerts with historical comparison
- On-call engineers know exactly who to escalate to and within what timeframe, based on a documented rotation and escalation matrix
- Maintenance windows are announced 72 hours in advance and excluded from SLA calculations

# Agent Contract

## Scope

- In scope:
  - SLI definitions for all production Open edX services (LMS, CMS, MFE, Caddy, Forum, Discovery, Ecommerce, Credentials, Notes, XQueue, Workers)
  - SLI definitions for infrastructure services (MySQL, Redis, Elasticsearch, MongoDB Atlas)
  - Service tier classification (Critical, Important, Optional) with per-tier availability targets
  - SLO targets with quantitative thresholds for availability, latency, error rate, and throughput
  - SLA contractual guarantees derived from SLOs with safety margin
  - Error budget calculation methodology and burn-down tracking
  - Error budget-based deployment gating mechanism
  - Performance regression detection rules and automated alerting
  - Maintenance window policies with advance notification requirements
  - Incident communication SLA with response time commitments per severity
  - On-call rotation structure and escalation procedures
  - SLI measurement infrastructure requirements (what needs to exist in Prometheus/Grafana/GCP Monitoring)
  - Monthly and quarterly SLA reporting structure and client communication templates
  - Integration with existing monitoring stack (Prometheus, GCP Monitoring, Grafana, Alertmanager)
- Out of scope:
  - Implementation of the observability stack itself (covered by `specs/observability-stack_spec.md`)
  - Backup and disaster recovery SLAs (covered by `specs/disaster-recovery-business-continuity_spec.md`)
  - Third-party SaaS SLAs (Cloudflare, MongoDB Atlas, GCP -- these are pass-through)
  - Financial penalties and credit structures for SLA breaches (legal/commercial decision)
  - Internal engineering team performance metrics (velocity, cycle time)
  - Cost optimization or FinOps SLOs
  - Development/staging environment SLOs (production only)

## Non-goals

- Achieving 99.99% ("four nines") availability -- the cost/complexity is not justified for the current scale
- Fully automated incident remediation without human approval for production changes
- Real-time SLA reporting to clients (monthly cadence is sufficient)
- SLO targets for individual course content or specific learning features (platform-level only)
- Replacing GCP Monitoring uptime checks with custom probe infrastructure
- Building a custom SLO management platform (use existing Prometheus + Grafana tooling)

## Assumptions

- Production runs on GKE Autopilot in `asia-southeast1-c` with namespace `mereka-lms`
- Prometheus (kube-prometheus-stack) is deployed in the `monitoring` namespace and scrapes `mereka-lms`
- GCP Cloud Monitoring uptime checks exist for all public endpoints (defined in `infrastructure/monitoring/uptime/`)
- VPS Prometheus at `prometheus.mereka.dev` provides external URL probes via blackbox exporter
- Grafana is accessible at `grafana.mereka.io` with datasources for GKE Prometheus and VPS Prometheus
- Alertmanager is configured with Slack notification channels
- ServiceMonitors exist for LMS, CMS, MySQL (mysqld-exporter), and Redis (redis-exporter)
- The team size is small (2-4 engineers) which constrains on-call rotation design
- Enterprise contracts are in negotiation; SLA numbers in this spec are proposals to be validated with sales/legal
- Monthly reporting cadence is sufficient for enterprise client communication

## Requirements

### Functional

#### Service Tier Definitions

- The system MUST classify every production service into one of three tiers:

  | Tier | Classification | Services | Rationale |
  |------|---------------|----------|-----------|
  | Tier 1: Critical | User-facing services that, if down, render the platform unusable | LMS, CMS, Caddy (reverse proxy), MySQL, Redis | Direct impact on all learners and instructors |
  | Tier 2: Important | Services that support key workflows but have partial degradation modes | MFE (micro-frontends), Forum, Discovery, Ecommerce, Credentials, Workers (Celery), Elasticsearch | Failure degrades specific features but core LMS remains functional |
  | Tier 3: Optional | Services that enhance the platform but are not required for core functionality | Notes, XQueue (legacy assessment), MongoDB Atlas (read path has caching) | Failure affects niche features only |

- The system MUST assign availability targets per tier:

  | Tier | Internal SLO | External SLA | Monthly Downtime Budget | Error Budget (30-day) |
  |------|-------------|--------------|------------------------|----------------------|
  | Tier 1: Critical | 99.95% | 99.9% | 4.38 minutes (SLO) / 43.8 minutes (SLA) | 21.6 minutes / 43.8 minutes |
  | Tier 2: Important | 99.9% | 99.5% | 43.8 minutes (SLO) / 3.6 hours (SLA) | 43.8 minutes / 3.6 hours |
  | Tier 3: Optional | 99.5% | 99.0% | 3.6 hours (SLO) / 7.3 hours (SLA) | 3.6 hours / 7.3 hours |

- The system MUST ensure the internal SLO is always stricter than the external SLA to provide a safety margin

#### SLI Definitions

- The system MUST define and measure the following SLIs for every production service:

  **Availability SLI**
  - The system MUST measure availability as: `(total_successful_requests / total_valid_requests) * 100` over a rolling 30-day window
  - A request MUST be classified as "successful" if it returns an HTTP status code in the range 2xx or 3xx
  - A request MUST be classified as "failed" if it returns an HTTP status code in the range 5xx
  - Requests returning 4xx MUST NOT count against availability (client errors are not platform failures)
  - The system MUST exclude requests during declared maintenance windows from both numerator and denominator

  **Latency SLI**
  - The system MUST measure request latency at the reverse proxy layer (Caddy) for user-facing services
  - The system MUST measure latency at the following percentiles: p50, p95, p99
  - The system MUST define latency targets per endpoint category:

    | Endpoint Category | p50 Target | p95 Target | p99 Target | Examples |
    |-------------------|-----------|-----------|-----------|----------|
    | LMS page loads | <= 500ms | <= 2,000ms | <= 5,000ms | `/courses/`, `/dashboard/`, homepage |
    | CMS (Studio) page loads | <= 800ms | <= 3,000ms | <= 8,000ms | `/course/`, `/container/`, unit editor |
    | MFE page loads | <= 300ms | <= 1,000ms | <= 3,000ms | `/authn/login`, `/account/`, `/dashboard/` |
    | API endpoints (REST) | <= 200ms | <= 800ms | <= 2,000ms | `/api/enrollment/v1/`, `/api/user/v1/` |
    | API endpoints (Bulk/Export) | <= 2,000ms | <= 10,000ms | <= 30,000ms | Grade exports, enrollment bulk operations |
    | Static assets (CDN/Caddy) | <= 50ms | <= 200ms | <= 500ms | CSS, JS, images |
    | Forum API | <= 300ms | <= 1,500ms | <= 4,000ms | Thread listing, post creation |
    | Discovery API | <= 200ms | <= 1,000ms | <= 3,000ms | Course search, catalog queries |

  **Error Rate SLI**
  - The system MUST measure error rate as: `(5xx_responses / total_responses) * 100` over a 5-minute sliding window
  - The system MUST define error rate thresholds:

    | Tier | Warning Threshold | Critical Threshold |
    |------|-------------------|-------------------|
    | Tier 1 | > 0.1% (5-min window) | > 1.0% (5-min window) |
    | Tier 2 | > 0.5% (5-min window) | > 2.0% (5-min window) |
    | Tier 3 | > 1.0% (5-min window) | > 5.0% (5-min window) |

  **Throughput SLI (Saturation)**
  - The system SHOULD measure throughput as requests per second (RPS) per service
  - The system MUST measure saturation signals for infrastructure services:

    | Component | Saturation Metric | Warning Threshold | Critical Threshold |
    |-----------|------------------|-------------------|-------------------|
    | MySQL | Connection utilization (threads_connected / max_connections) | > 70% | > 85% |
    | MySQL | Slow queries (increase over 10 min) | > 10 | > 20 |
    | Redis | Memory utilization (used_memory / maxmemory) | > 70% | > 85% |
    | Redis | Connection utilization | > 70% | > 85% |
    | Redis | Evictions (increase over 15 min) | > 0 | > 100 |
    | Elasticsearch | Heap utilization | > 75% | > 90% |
    | Caddy | Active connections | > 1,000 | > 2,000 |
    | LMS/CMS pods | CPU request utilization | > 75% | > 90% |
    | LMS/CMS pods | Memory request utilization | > 80% | > 90% |

#### Error Budget Calculation and Tracking

- The system MUST calculate error budgets on a 30-day rolling window for each service
- Error budget MUST be calculated as: `error_budget_remaining = (1 - SLO_target) * total_minutes_in_window - total_downtime_minutes`
- The system MUST track error budget consumption rate (burn rate) using multi-window alerting:

  | Alert Level | Fast Burn (1h window) | Slow Burn (6h window) | Action |
  |-------------|----------------------|----------------------|--------|
  | Page (P1) | > 14.4x budget rate | > 6x budget rate | Immediate page to on-call |
  | Ticket (P2) | > 6x budget rate | > 3x budget rate | Create incident ticket within 1 hour |
  | Warning (P3) | > 3x budget rate | > 1x budget rate | Investigate within business hours |

- The system MUST expose error budget metrics in Prometheus:

  | Metric Name | Type | Labels | Description |
  |-------------|------|--------|-------------|
  | `mereka_slo_availability_ratio` | Gauge | `service`, `tier` | Current availability ratio (0-1) |
  | `mereka_slo_error_budget_remaining_ratio` | Gauge | `service`, `tier` | Remaining error budget as ratio (0-1) |
  | `mereka_slo_error_budget_remaining_minutes` | Gauge | `service`, `tier` | Remaining error budget in minutes |
  | `mereka_slo_latency_p95_seconds` | Gauge | `service`, `endpoint_category` | Current p95 latency |
  | `mereka_slo_latency_budget_ratio` | Gauge | `service`, `endpoint_category` | Ratio of requests within latency SLO |

- The system MUST display error budget status on a dedicated Grafana dashboard (`Mereka LMS - SLO Overview`)
- The system SHOULD display a 30-day trend of error budget consumption on the SLO dashboard

#### Deployment Gating

- The system MUST gate production deployments based on error budget status:

  | Error Budget Remaining | Deployment Policy | Approval Required |
  |----------------------|-------------------|-------------------|
  | >= 50% | Normal: deploy freely | None (automated CI/CD) |
  | 25% - 49% | Cautious: deploy with monitoring | Engineering lead approval |
  | 10% - 24% | Restricted: critical fixes only | Engineering lead + product approval |
  | < 10% | Frozen: no deployments except incident remediation | VP/CTO approval |

- The system MUST implement deployment gating as a CI/CD pipeline check that queries the `mereka_slo_error_budget_remaining_ratio` metric
- The system MUST allow emergency override of the deployment gate with documented justification
- The system MUST log every deployment gate override including: who, when, why, and what was deployed
- The system SHOULD automatically notify the engineering channel when deployment policy changes tier (e.g., Normal -> Cautious)

#### Maintenance Window Policies

- The system MUST define maintenance windows with the following constraints:

  | Policy | Requirement |
  |--------|-------------|
  | Advance notice | MUST notify enterprise clients at least 72 hours before a scheduled maintenance window |
  | Preferred window | SHOULD schedule maintenance during low-traffic hours: 02:00-06:00 UTC (10:00-14:00 MYT) on weekdays, or weekends |
  | Maximum duration | MUST NOT exceed 4 hours per maintenance window |
  | Maximum frequency | MUST NOT schedule more than 2 maintenance windows per calendar month |
  | Emergency maintenance | MAY perform emergency maintenance with less than 72 hours notice for P1 incidents, with immediate notification |
  | SLA exclusion | MUST exclude declared maintenance window duration from SLA availability calculations |
  | Notification channels | MUST notify via: email to enterprise account contacts, status page update at `status.mereka.dev`, and Slack channel |

- The system MUST maintain a maintenance calendar accessible to enterprise clients
- The system MUST record all maintenance windows with start time, end time, scope, and outcome

#### Incident Communication SLA

- The system MUST define incident response time commitments per severity:

  | Severity | Detection Time | Acknowledgement | First Update | Resolution Target | Status Updates |
  |----------|---------------|-----------------|--------------|-------------------|----------------|
  | P1 (Critical) | <= 5 minutes (automated) | <= 15 minutes | <= 30 minutes | <= 4 hours | Every 30 minutes |
  | P2 (High) | <= 15 minutes (automated) | <= 30 minutes | <= 1 hour | <= 8 hours | Every 2 hours |
  | P3 (Medium) | <= 1 hour | <= 4 hours | <= 8 hours | <= 24 hours (business) | Daily |
  | P4 (Low) | Next business day | Next business day | Within 2 business days | <= 5 business days | On resolution |

- The system MUST define severity classification criteria:

  | Severity | Criteria |
  |----------|----------|
  | P1 (Critical) | Complete platform outage; all users affected; data loss risk; Tier 1 service fully down |
  | P2 (High) | Partial outage; specific workflows broken; Tier 1 service degraded or Tier 2 service fully down |
  | P3 (Medium) | Single feature unavailable; Tier 2 service degraded or Tier 3 service down; workaround available |
  | P4 (Low) | Cosmetic issue; performance degradation below alert threshold; monitoring gap |

- The system MUST publish incident postmortems within 5 business days of P1/P2 resolution
- Each postmortem MUST include: timeline, root cause, impact scope, remediation actions, and prevention measures
- The system MUST maintain an incident log accessible to enterprise clients (sanitized of internal implementation details)

#### On-Call Rotation and Escalation

- The system MUST define an on-call rotation with the following structure:

  | Role | Responsibility | Response Time | Rotation |
  |------|---------------|---------------|----------|
  | Primary On-Call | First responder for all alerts; triage and initial remediation | <= 15 minutes for P1, <= 30 minutes for P2 | Weekly rotation |
  | Secondary On-Call | Backup if primary is unreachable; escalation point for complex issues | <= 30 minutes for P1, <= 1 hour for P2 | Weekly rotation (offset) |
  | Incident Commander | Coordinates response for P1/P2; owns communication; declares resolution | Engaged for all P1, optionally for P2 | Engineering lead (fixed) |

- The system MUST define an escalation matrix:

  | Escalation Tier | Trigger | Escalation Target | Time Limit |
  |-----------------|---------|-------------------|------------|
  | L1 | Alert fires | Primary on-call | 15 minutes to acknowledge |
  | L2 | Primary does not acknowledge within 15 minutes OR cannot resolve within 30 minutes | Secondary on-call | 15 minutes to acknowledge |
  | L3 | Secondary does not acknowledge within 15 minutes OR issue persists > 1 hour | Incident Commander (engineering lead) | 15 minutes to acknowledge |
  | L4 | Issue persists > 2 hours OR data loss confirmed | VP/CTO | Immediate |

- The system MUST maintain on-call schedule in a tool accessible to all engineers (Slack, PagerDuty, or documented in wiki)
- The system MUST NOT require a single engineer to be on-call for more than 7 consecutive days
- The system SHOULD provide on-call handoff documentation at each rotation change

#### Performance Regression Detection

- The system MUST detect performance regressions by comparing current latency metrics against a 7-day rolling baseline
- The system MUST alert when any of the following conditions are met:

  | Regression Type | Detection Rule | Alert Severity |
  |----------------|----------------|----------------|
  | Latency spike | p95 latency exceeds 2x the 7-day p95 baseline for 15 minutes | P2 |
  | Latency drift | p95 latency exceeds 1.5x the 7-day p95 baseline for 1 hour | P3 |
  | Error rate spike | 5xx error rate exceeds 3x the 7-day average for 10 minutes | P1 |
  | Error rate drift | 5xx error rate exceeds 2x the 7-day average for 30 minutes | P2 |
  | Throughput drop | RPS drops below 50% of the 7-day average for 15 minutes (during business hours) | P2 |

- The system MUST correlate performance regressions with recent deployments by annotating deployment events on Grafana dashboards
- The system SHOULD automatically identify the most recent deployment as a potential cause when regression is detected within 30 minutes of deploy
- The system MUST retain performance baseline data for at least 90 days to support trend analysis

#### SLI Measurement Infrastructure

- The system MUST implement SLI measurement using the following infrastructure components:

  | Component | Purpose | Source |
  |-----------|---------|--------|
  | Prometheus recording rules | Pre-aggregate SLI metrics from raw counters into rolling window ratios | GKE Prometheus (`monitoring` namespace) |
  | Grafana SLO dashboard | Visualize SLO compliance, error budgets, and burn rates | `grafana.mereka.io` |
  | GCP uptime checks | External availability probes every 5 minutes from multiple regions | `infrastructure/monitoring/uptime/` |
  | VPS blackbox exporter | External latency and certificate monitoring | `prometheus.mereka.dev` |
  | PrometheusRule CRD | Burn rate and regression alerts | `deploy/k8s/base/monitoring/` |
  | Alertmanager | Alert routing for SLO breaches to on-call | Existing Alertmanager in `monitoring` namespace |

- The system MUST create Prometheus recording rules for each SLI:

  | Recording Rule | Expression (simplified) | Interval |
  |---------------|------------------------|----------|
  | `mereka:http_requests:availability_ratio_5m` | `1 - (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]))` | 30s |
  | `mereka:http_requests:availability_ratio_30d` | `1 - (increase(http_requests_total{status=~"5.."}[30d]) / increase(http_requests_total[30d]))` | 5m |
  | `mereka:http_request_duration:p95_5m` | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | 30s |
  | `mereka:http_request_duration:p99_5m` | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` | 30s |
  | `mereka:slo:error_budget_remaining_ratio` | `1 - ((1 - mereka:http_requests:availability_ratio_30d) / (1 - <SLO_TARGET>))` | 5m |

- The system MUST ensure `django-prometheus` or equivalent middleware is installed in LMS/CMS to expose `http_request_duration_seconds` histogram metrics
- The system MUST ensure Caddy access logs or metrics expose request duration for all proxied services

#### Monthly and Quarterly Reporting

- The system MUST generate a monthly SLA compliance report containing:
  - Per-service availability percentage for the reporting period
  - Per-service latency distribution (p50, p95, p99) for the reporting period
  - Error budget consumption summary (remaining budget, burn rate trend)
  - Incident summary (count by severity, MTTR, root cause categories)
  - Maintenance window log (dates, duration, scope)
  - SLA compliance status (PASS/FAIL per service per tier)
  - Trend comparison against previous month

- The system MUST generate a quarterly SLA compliance report that additionally includes:
  - 90-day availability trend per service
  - Performance regression incidents and resolution
  - Capacity planning recommendations based on saturation trends
  - On-call health metrics (alert volume, escalation frequency, after-hours pages)
  - Recommendations for SLO target adjustments based on observed reliability

- The system SHOULD automate report generation via a scheduled script or CI pipeline
- The system MUST retain SLA reports for at least 24 months
- The system MUST distribute monthly reports to enterprise account contacts within 5 business days of month end
- Enterprise clients MUST receive quarterly business reviews including the SLA report within 10 business days of quarter end

### Non-functional (NFRs)

#### Performance

- SLI metric collection MUST NOT increase LMS/CMS request latency by more than 5ms at p99
- Prometheus recording rules MUST evaluate within 30 seconds of the configured interval
- SLO dashboard MUST load within 5 seconds in Grafana
- Error budget calculation MUST update within 5 minutes of any availability change

#### Reliability

- SLI measurement infrastructure MUST be independent of the measured services (Prometheus in `monitoring` namespace, not `mereka-lms`)
- Loss of SLI measurement MUST trigger a P2 alert within 5 minutes
- SLI data MUST be retained in Prometheus for at least 30 days (matching the SLO window)
- SLI data SHOULD be retained for 90 days via long-term storage (Thanos or GCS export) for trend analysis

#### Security

- SLA reports distributed to enterprise clients MUST NOT contain internal infrastructure details (IP addresses, secret names, internal hostnames)
- SLA reports MUST be delivered via secure channels (encrypted email, authenticated portal, or direct download link with expiry)
- Error budget metrics MUST NOT expose sensitive request data (PII, credentials, request bodies)
- On-call contact information MUST be accessible only to authorized personnel

#### Observability (Meta)

- The SLI measurement system itself MUST expose health metrics (scrape success rate, recording rule evaluation latency)
- The system MUST alert if SLI data collection fails for any service for more than 10 minutes
- The system MUST track and alert on Prometheus storage utilization to prevent SLI data loss

## Acceptance Criteria

### Service Tier Classification

- [ ] AC-001: Given the service tier table, when `kubectl get deploy -n mereka-lms` is run, then every listed deployment maps to exactly one tier as defined in this spec
- [ ] AC-002: Given each tier definition, when the availability SLO target is compared to the external SLA target, then the SLO is strictly more stringent (higher percentage) than the SLA for every tier

### SLI Measurement

- [ ] AC-003: Given LMS is running, when `curl -s https://academyv2.mereka.io/metrics | grep http_request_duration_seconds` is run, then histogram buckets are returned showing request latency distribution
- [ ] AC-004: Given Prometheus is running, when `promtool query instant http://prometheus:9090 'mereka:http_requests:availability_ratio_5m{service="lms"}'` is executed, then a value between 0 and 1 is returned
- [ ] AC-005: Given all recording rules are deployed, when `kubectl get prometheusrule -n mereka-lms -o yaml | grep "record: mereka:"` is run, then all recording rules defined in this spec are present
- [ ] AC-006: Given GCP uptime checks are active, when `gcloud monitoring uptime list-configs --project=mereka-lms --format=json` is run, then checks exist for all Tier 1 and Tier 2 service public endpoints

### Error Budget

- [ ] AC-007: Given 30 days of metrics data, when the `mereka:slo:error_budget_remaining_ratio` recording rule is queried for each service, then values are returned showing remaining budget as a ratio between 0 and 1
- [ ] AC-008: Given the SLO dashboard exists in Grafana, when `https://grafana.mereka.io/d/mereka-slo-overview` is loaded, then panels display: per-service availability ratio, error budget remaining, burn rate trend, and latency distributions
- [ ] AC-009: Given error budget drops below 50%, when the burn rate alert evaluates, then a Slack notification is sent to the engineering channel within 5 minutes

### Deployment Gating

- [ ] AC-010: Given error budget is >= 50% for all Tier 1 services, when a deployment pipeline runs, then the deployment gate check passes without manual approval
- [ ] AC-011: Given error budget is < 25% for any Tier 1 service, when a deployment pipeline runs, then the gate check blocks deployment and requires documented approval
- [ ] AC-012: Given an emergency deployment override occurs, when the override is logged, then the log entry contains: approver, timestamp, justification, and deployment identifier

### Performance Regression Detection

- [ ] AC-013: Given a stable 7-day latency baseline, when p95 latency exceeds 2x the baseline for 15 consecutive minutes, then a P2 alert fires and is delivered to on-call
- [ ] AC-014: Given a deployment event, when regression is detected within 30 minutes of the deployment, then the alert annotation includes the deployment identifier and commit SHA
- [ ] AC-015: Given deployment events are annotated in Grafana, when the SLO dashboard is viewed, then vertical markers appear at each deployment timestamp on latency and availability panels

### Maintenance Windows

- [ ] AC-016: Given a maintenance window is declared 72 hours in advance, when SLA availability is calculated for the month, then the maintenance window duration is excluded from both numerator and denominator
- [ ] AC-017: Given a maintenance window record, when the monthly SLA report is generated, then the maintenance window appears in the report with start time, end time, and scope

### Incident Communication

- [ ] AC-018: Given a P1 incident is declared, when the on-call engineer acknowledges, then acknowledgement occurs within 15 minutes of alert firing
- [ ] AC-019: Given a P1/P2 incident is resolved, when the postmortem is published, then it is published within 5 business days and contains: timeline, root cause, impact, remediation, and prevention sections

### On-Call

- [ ] AC-020: Given the on-call schedule, when any week is inspected, then a primary and secondary on-call engineer are assigned and no engineer has consecutive on-call duty exceeding 7 days
- [ ] AC-021: Given a P1 alert fires, when the primary on-call does not acknowledge within 15 minutes, then the alert automatically escalates to the secondary on-call

### Reporting

- [ ] AC-022: Given one month of production operation, when the monthly SLA report script runs, then a report is generated containing per-service availability, latency percentiles, error budget status, incident summary, and maintenance log
- [ ] AC-023: Given a generated SLA report, when reviewed for security, then it contains no internal IP addresses, secret names, or infrastructure hostnames

## Edge Cases

### SLI Data Gap Due to Prometheus Restart

**Symptom**: Missing SLI data points during Prometheus pod restart or upgrade.

**Impact**: Availability calculation may be overly optimistic (missing failures) or pessimistic (missing successes).

**Mitigation**:
- The system MUST use `rate()` and `increase()` functions that handle counter resets
- The system MUST use GCP uptime checks as an independent external availability signal to fill internal gaps
- The system SHOULD use Thanos or remote write to a secondary store for gap-free SLI data
- If a gap exceeds 30 minutes, the system MUST document it in the monthly report as a measurement gap

### Error Budget Exhaustion During Incident

**Symptom**: Error budget drops to 0% during an extended P1 incident. All subsequent deployments are frozen.

**Mitigation**:
- Incident remediation deployments MUST be exempt from the deployment freeze (requires documented override)
- After error budget exhaustion, the system MUST enter a "reliability sprint" mode where only reliability-improving changes are deployed for 7 days
- Error budget resets at the rolling 30-day window boundary (no hard monthly reset)
- The system MUST NOT allow budget exhaustion to prevent fixing the incident itself

### Maintenance Window Overrun

**Symptom**: Maintenance window exceeds the declared 4-hour maximum.

**Mitigation**:
- The system MUST alert operations when the maintenance window reaches 75% of declared duration (3 hours)
- If maintenance exceeds declared duration, the overage MUST count against SLA availability
- The system MUST log the overrun with root cause in the maintenance record
- Extended maintenance MUST trigger an additional client notification explaining the delay

### Conflicting SLI Signals (Internal vs External)

**Symptom**: GCP uptime check shows service as available but internal Prometheus shows errors (or vice versa).

**Cause**: Network partitioning, DNS cache inconsistency, or probe location differences.

**Mitigation**:
- For SLA calculation, the system MUST use the external (GCP uptime check) signal as the authoritative availability indicator because it represents the client experience
- For internal operations, the system MUST use Prometheus metrics for granular triage
- The system MUST alert on signal divergence (internal healthy but external failing, or vice versa) as it indicates a monitoring blind spot
- Retry/timeout behavior: GCP uptime checks retry from multiple regions; a failure requires probe failures from at least 2 of 6 regions

### Latency Percentile Skew from Background Jobs

**Symptom**: p95 latency spikes due to heavy Celery worker API calls (grade exports, enrollment syncs).

**Cause**: Background job traffic inflates latency metrics for user-facing endpoints.

**Mitigation**:
- The system MUST separate SLI measurement for user-facing and background traffic using request labels (User-Agent, endpoint path prefix)
- If labels cannot distinguish traffic, the system SHOULD exclude known bulk API paths (`/api/bulk_enroll/`, `/api/grades/export/`) from latency SLI calculation
- The "Bulk/Export" endpoint category has separate, looser latency targets for this reason

### Rate Limiting False Positives

**Symptom**: Availability drops because legitimate requests hit rate limits (HTTP 429) which are classified as failures.

**Mitigation**:
- HTTP 429 responses MUST NOT count against availability SLIs (rate limiting is a protection mechanism, not a failure)
- The system MUST track rate-limited request volume as a separate metric for capacity planning
- Sustained rate limiting of legitimate traffic (>5% of requests) MUST trigger a capacity review

### SLO Target Adjustment After Baseline Period

**Symptom**: Initial SLO targets are too aggressive or too lenient based on observed reliability.

**Mitigation**:
- SLO targets MUST be reviewed quarterly based on actual measured reliability
- SLO targets MUST NOT be loosened to match poor reliability -- instead, reliability improvements are required
- SLO targets MAY be tightened if observed reliability consistently exceeds the target by >2x the margin
- Any SLO target change MUST be communicated to enterprise clients 30 days before the SLA is updated

### Partial Degradation Not Captured by Binary Availability

**Symptom**: Platform is "up" (returning 200s) but user experience is severely degraded (10-second page loads).

**Mitigation**:
- The system MUST use a composite SLI that combines availability AND latency: a request is "good" only if it returns 2xx/3xx AND completes within the p99 latency target
- This composite SLI prevents "technically available but unusable" from counting as a healthy state
- The latency-included availability MUST be reported alongside the pure HTTP availability in SLA reports

## Observability

### Logs

- SLO compliance status changes (budget crossing thresholds) MUST be logged with structured fields: `{event: "slo_budget_threshold_crossed", service: "<name>", tier: "<tier>", remaining_pct: <N>, threshold: "<level>"}`
- Deployment gate decisions MUST be logged: `{event: "deployment_gate_decision", service: "<name>", budget_remaining_pct: <N>, decision: "allow|block|override", approver: "<name>"}`
- Maintenance window declarations MUST be logged: `{event: "maintenance_window", action: "declared|started|ended|overrun", start: "<ISO8601>", end: "<ISO8601>", scope: "<description>"}`
- Incident lifecycle events MUST be logged: `{event: "incident", action: "declared|acknowledged|updated|resolved", severity: "P1|P2|P3|P4", incident_id: "<id>"}`

### Metrics

| Metric | Type | Labels | Source |
|--------|------|--------|--------|
| `mereka_slo_availability_ratio` | Gauge | `service`, `tier` | Prometheus recording rule |
| `mereka_slo_error_budget_remaining_ratio` | Gauge | `service`, `tier` | Prometheus recording rule |
| `mereka_slo_error_budget_remaining_minutes` | Gauge | `service`, `tier` | Prometheus recording rule |
| `mereka_slo_latency_p50_seconds` | Gauge | `service`, `endpoint_category` | Prometheus recording rule |
| `mereka_slo_latency_p95_seconds` | Gauge | `service`, `endpoint_category` | Prometheus recording rule |
| `mereka_slo_latency_p99_seconds` | Gauge | `service`, `endpoint_category` | Prometheus recording rule |
| `mereka_slo_latency_budget_ratio` | Gauge | `service`, `endpoint_category` | Prometheus recording rule |
| `mereka_slo_burn_rate_1h` | Gauge | `service`, `tier` | Prometheus recording rule |
| `mereka_slo_burn_rate_6h` | Gauge | `service`, `tier` | Prometheus recording rule |
| `mereka_incident_count_total` | Counter | `severity` | Custom exporter or log metric |
| `mereka_incident_mttr_seconds` | Histogram | `severity` | Custom exporter or log metric |
| `mereka_deployment_gate_decisions_total` | Counter | `decision` (allow, block, override) | CI/CD pipeline metric |
| `mereka_maintenance_window_seconds_total` | Counter | `scope` | Manual annotation or log metric |

### Alerts

| Alert Name | Severity | Condition | Routing |
|------------|----------|-----------|---------|
| `SLOBudgetFastBurn` | P1 | 1h burn rate > 14.4x AND 5m burn rate > 14.4x for any Tier 1 service | Page primary on-call immediately |
| `SLOBudgetSlowBurn` | P2 | 6h burn rate > 6x AND 30m burn rate > 6x for any Tier 1 service | Page primary on-call |
| `SLOBudgetWarning` | P3 | 6h burn rate > 3x for any Tier 1/2 service | Slack engineering channel |
| `SLOBudgetExhausted` | P1 | Error budget remaining < 0% for any Tier 1 service | Page primary + secondary on-call; notify Incident Commander |
| `SLOBudgetLow` | P2 | Error budget remaining < 25% for any Tier 1 service | Slack engineering channel + email to engineering lead |
| `LatencyRegressionSpike` | P2 | p95 latency > 2x 7-day baseline for 15 minutes | Page primary on-call |
| `LatencyRegressionDrift` | P3 | p95 latency > 1.5x 7-day baseline for 1 hour | Slack engineering channel |
| `ErrorRateSpike` | P1 | 5xx error rate > 3x 7-day average for 10 minutes | Page primary + secondary on-call |
| `SLIMeasurementDown` | P2 | No SLI data for any Tier 1 service for 10 minutes | Page primary on-call |
| `MaintenanceWindowOverrun` | P3 | Maintenance window has reached 75% of declared duration | Slack operations channel |

### Dashboards

The system MUST create or update the following Grafana dashboards:

| Dashboard | UID | Panels |
|-----------|-----|--------|
| `Mereka LMS - SLO Overview` | `mereka-slo-overview` | Per-service availability (30-day rolling), error budget remaining (bar chart), burn rate trend (time series), latency percentiles by endpoint category, deployment annotations, maintenance window markers |
| `Mereka LMS - SLO Detail` (per service) | `mereka-slo-detail-{service}` | Individual service deep-dive: availability ratio, error budget burn-down, latency histogram heatmap, error rate trend, saturation metrics, top slow endpoints |
| `Mereka LMS - Error Budget` | `mereka-error-budget` | Budget remaining per tier (gauge), budget consumption timeline (stacked area), deployment freeze status (indicator), budget forecast (when budget hits zero at current burn rate) |

## Rollout & Rollback

### Rollout Plan

This spec is implemented incrementally. Each phase has a gate that must pass before proceeding.

**Phase 1 -- SLI Foundation (Week 1-2)**
1. Verify `django-prometheus` is installed and exposing `http_request_duration_seconds` from LMS/CMS
2. Verify Caddy is logging/exporting request latency metrics
3. Create Prometheus recording rules for availability ratio (5m, 30d) and latency percentiles (p50, p95, p99)
4. Create `PrometheusRule` CRD in `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
5. Verify recording rules produce data: `promtool query instant` for each rule
6. Gate: All recording rules return valid data for LMS and CMS

**Phase 2 -- Error Budget and Dashboard (Week 3-4)**
1. Create Prometheus recording rules for error budget calculation (remaining ratio, remaining minutes, burn rates)
2. Create `Mereka LMS - SLO Overview` dashboard in Grafana with all required panels
3. Create burn rate alert rules (SLOBudgetFastBurn, SLOBudgetSlowBurn, SLOBudgetWarning, SLOBudgetExhausted, SLOBudgetLow)
4. Verify alerts fire correctly by simulating error injection in a test endpoint
5. Gate: Dashboard loads within 5 seconds and shows data for all Tier 1 services; burn rate alerts are testable

**Phase 3 -- Deployment Gating (Week 5-6)**
1. Implement deployment gate check script (`scripts/qa/check-error-budget-gate.sh`) that queries `mereka_slo_error_budget_remaining_ratio`
2. Integrate gate check into CI/CD pipeline (GitHub Actions) as a required step before production deploy
3. Implement override mechanism with logging
4. Test gate behavior at each budget threshold (>= 50%, 25-49%, 10-24%, <10%)
5. Gate: Gate correctly blocks deployment when budget is below threshold; override works with audit log

**Phase 4 -- Performance Regression Detection (Week 7-8)**
1. Create Prometheus recording rules for 7-day rolling baseline (p95 latency, error rate, throughput)
2. Create regression detection alert rules (LatencyRegressionSpike, LatencyRegressionDrift, ErrorRateSpike)
3. Add deployment event annotations to Grafana dashboards
4. Test regression detection by introducing artificial latency in test endpoint
5. Gate: Regression alert fires within 15 minutes of simulated degradation

**Phase 5 -- Process and Reporting (Week 9-12)**
1. Document on-call rotation schedule and escalation matrix
2. Document maintenance window policies and create maintenance calendar
3. Create incident communication templates (declaration, update, resolution, postmortem)
4. Create monthly SLA report generation script (`scripts/qa/generate-sla-report.sh`)
5. Generate first monthly SLA report from production data
6. Distribute to enterprise accounts for feedback
7. Gate: Monthly report is generated, reviewed, and distributed successfully

### Feature Flags

- `ENABLE_DEPLOYMENT_GATING` (GitHub Actions repo variable): When `true`, the deployment gate check blocks on error budget. Default: `false` during Phase 1-2, `true` from Phase 3.
- `SLO_ALERT_ROUTING` (Alertmanager config): Controls whether SLO burn rate alerts page on-call or go to Slack only. Default: Slack-only during Phase 1-2, page-capable from Phase 3.
- `STRICT_SLO_MEASUREMENT` (environment variable): When `1`, SLI measurement scripts fail on missing data instead of warning. Default: `0` during rollout, `1` after Phase 2 gate.

### Backward Compatibility

- This spec does not modify any existing monitoring infrastructure -- it adds new recording rules, alerts, and dashboards
- Existing alert severity matrix (ALERT_SEVERITY_MATRIX.md) is not replaced but extended with SLO-specific alerts
- Existing uptime checks and alerts continue to operate independently
- No changes to application code are required if `django-prometheus` is already installed; only recording rule deployment

### Rollback Steps

If any phase introduces issues:

1. **Phase 1**: Delete recording rules: `kubectl delete prometheusrule slo-recording-rules -n mereka-lms`. No impact on existing monitoring.
2. **Phase 2**: Delete SLO dashboard in Grafana UI; delete burn rate alerts from PrometheusRule. Error budget metrics disappear but no operational impact.
3. **Phase 3**: Set `ENABLE_DEPLOYMENT_GATING=false` in GitHub Actions. Deployments proceed without gate check. Remove gate check step from CI workflow.
4. **Phase 4**: Delete regression detection rules from PrometheusRule. Remove deployment annotations from Grafana. No operational impact.
5. **Phase 5**: Process changes are documented, not deployed infrastructure. Rollback is simply ceasing the new reporting cadence.

## Open Questions

1. **Enterprise SLA contractual numbers**: This spec proposes 99.9% (Tier 1 SLA), 99.5% (Tier 2), 99.0% (Tier 3). What numbers have been discussed or promised in enterprise sales conversations? These need validation with sales/legal before the SLA becomes contractual. The DR spec (open question #3) asks the same question.
2. **Financial penalties for SLA breach**: What are the financial implications of missing SLA targets? Service credits, refunds, or contractual termination rights? This determines how conservative the SLA safety margin needs to be.
3. **django-prometheus installation status**: Is `django-prometheus` currently installed and exposing the `http_request_duration_seconds` histogram in production LMS/CMS? The observability spec mentions it as a plan but it may not be deployed yet. This is a prerequisite for Phase 1.
4. **Caddy access log metrics**: Does the Caddy reverse proxy currently export request duration metrics to Prometheus? If not, this requires Caddy configuration changes (enable Prometheus metrics module).
5. **PagerDuty or equivalent**: Is there budget/willingness to adopt PagerDuty (or Opsgenie/Grafana OnCall) for on-call scheduling and escalation? The current setup uses Slack; automated phone escalation requires a dedicated tool.
6. **On-call team size**: With 2-4 engineers, a weekly rotation means the same person is on-call frequently. Is the team comfortable with this cadence, or should on-call be bi-weekly with reduced off-hours expectations?
7. **Thanos or long-term storage**: Is long-term metric storage (Thanos, Cortex, or GCS export) planned? 30-day Prometheus retention supports the SLO window but limits trend analysis. The observability spec (open question #1) asks the same.
8. **Client portal for SLA reports**: Should SLA reports be delivered via email, a client portal (e.g., shared Google Drive), or an authenticated web dashboard? This affects the reporting automation design.
9. **Composite SLI adoption**: Should the SLA contract use the composite SLI (availability AND latency) or the simpler HTTP-only availability? Composite is more accurate but harder for clients to verify independently.
10. **Existing Caddy metrics port**: Does the Caddy deployment currently expose a metrics port and ServiceMonitor? If not, this is a Phase 1 prerequisite that needs infrastructure changes.
11. **Alert routing for SLO breaches**: Should SLO burn rate alerts go through the existing Slack webhook, or should a separate high-priority channel be created for SLO/SLA alerts?
12. **Monthly reporting start date**: When should the first monthly SLA report be generated? Immediately after Phase 2 (even if incomplete), or only after Phase 5 is complete?
