---
title: "SLO/SLA Definitions & Service Level Management"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
id: "SPEC-SLO-001"
spec_class: "integration"
created: "2026-02-10"
last_reviewed: "2026-02-10"
review_due: "2026-05-11"
domain: "platform"
normativity: "normative"
supersedes: []
superseded_by: null
verification_sources: []
interfaces: []
tags:
  - "observability.slo"
  - "observability.sla"
  - "runtime.reliability"
summary: "Defines service-level indicators, objectives, agreements, and operational management expectations for the platform."
depends_on:
  - "specs/observability-stack_spec.md"
links:
  related_docs:
    - "docs/ops/runbooks/SLO_DASHBOARDS_SETUP.md"
    - "docs/reference/operations/MONITORING.md"
    - "docs/reference/operations/ALERT_SEVERITY_MATRIX.md"
    - "docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/policies/operations/OBSERVABILITY_OWNERSHIP.md"
    - "docs/status/active/OBSERVABILITY_ENHANCEMENT_PLAN.md"
    - "docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/ops/runbooks/DISASTER_RECOVERY.md"
  related_specs:
    - "specs/observability-stack_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
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

#### Service-Specific SLI Implementations

- The system MUST implement the following concrete SLI measurements per service:

  **LMS (Learning Management System)**
  - SLI metric name: `mereka_sli_lms_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="lms", status=~"5.."}[5m]) / rate(http_requests_total{service="lms"}[5m]))`
  - Data source: LMS `/metrics` endpoint (django-prometheus), scraped by Prometheus every 30 seconds
  - Latency metric: `mereka_sli_lms_latency_p95_seconds` from `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service="lms"}[5m]))`
  - Error budget calculation: `mereka_sli_lms_error_budget_remaining_minutes = (30d * 24h * 60m * 0.0005) - total_downtime_minutes` (Tier 1 SLO: 99.95%)

  **CMS (Studio)**
  - SLI metric name: `mereka_sli_cms_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="cms", status=~"5.."}[5m]) / rate(http_requests_total{service="cms"}[5m]))`
  - Data source: CMS `/metrics` endpoint (django-prometheus), scraped by Prometheus every 30 seconds
  - Latency metric: `mereka_sli_cms_latency_p95_seconds` from `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service="cms"}[5m]))`
  - Error budget calculation: `mereka_sli_cms_error_budget_remaining_minutes = (30d * 24h * 60m * 0.0005) - total_downtime_minutes` (Tier 1 SLO: 99.95%)

  **MFE (Micro-Frontends)**
  - SLI metric name: `mereka_sli_mfe_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="mfe", status=~"5.."}[5m]) / rate(http_requests_total{service="mfe"}[5m]))`
  - Data source: Caddy reverse proxy metrics (proxied requests to MFE endpoints), scraped by Prometheus every 30 seconds
  - Latency metric: `mereka_sli_mfe_latency_p95_seconds` from Caddy request duration histograms
  - Error budget calculation: `mereka_sli_mfe_error_budget_remaining_minutes = (30d * 24h * 60m * 0.001) - total_downtime_minutes` (Tier 2 SLO: 99.9%)

  **Forum (openedx-forum)**
  - SLI metric name: `mereka_sli_forum_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="forum", status=~"5.."}[5m]) / rate(http_requests_total{service="forum"}[5m]))`
  - Data source: Forum service metrics (if exposed), otherwise Caddy reverse proxy metrics for `/api/discussion/` endpoints
  - Latency metric: `mereka_sli_forum_latency_p95_seconds` from request duration histograms
  - Error budget calculation: `mereka_sli_forum_error_budget_remaining_minutes = (30d * 24h * 60m * 0.001) - total_downtime_minutes` (Tier 2 SLO: 99.9%)

  **Ecommerce**
  - SLI metric name: `mereka_sli_ecommerce_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="ecommerce", status=~"5.."}[5m]) / rate(http_requests_total{service="ecommerce"}[5m]))`
  - Data source: Ecommerce service `/metrics` endpoint, scraped by Prometheus every 30 seconds
  - Latency metric: `mereka_sli_ecommerce_latency_p95_seconds` from request duration histograms
  - Error budget calculation: `mereka_sli_ecommerce_error_budget_remaining_minutes = (30d * 24h * 60m * 0.001) - total_downtime_minutes` (Tier 2 SLO: 99.9%)

  **Discovery**
  - SLI metric name: `mereka_sli_discovery_availability_ratio`
  - Calculation formula: `1 - (rate(http_requests_total{service="discovery", status=~"5.."}[5m]) / rate(http_requests_total{service="discovery"}[5m]))`
  - Data source: Discovery API metrics endpoint, scraped by Prometheus every 30 seconds
  - Latency metric: `mereka_sli_discovery_latency_p95_seconds` from request duration histograms
  - Error budget calculation: `mereka_sli_discovery_error_budget_remaining_minutes = (30d * 24h * 60m * 0.001) - total_downtime_minutes` (Tier 2 SLO: 99.9%)

  **MySQL (Cloud SQL)**
  - SLI metric name: `mereka_sli_mysql_availability_ratio`
  - Calculation formula: Derived from GCP Cloud SQL uptime monitoring API
  - Data source: GCP Cloud Monitoring API, polled every 5 minutes
  - Saturation metrics: `mereka_sli_mysql_connection_utilization_ratio` from `mysql_global_status_threads_connected / mysql_global_variables_max_connections` (mysqld-exporter)
  - Error budget calculation: `mereka_sli_mysql_error_budget_remaining_minutes = (30d * 24h * 60m * 0.0005) - total_downtime_minutes` (Tier 1 SLO: 99.95%)

  **Redis**
  - SLI metric name: `mereka_sli_redis_availability_ratio`
  - Calculation formula: `1 - (rate(redis_commands_failed_total[5m]) / rate(redis_commands_total[5m]))`
  - Data source: Redis exporter metrics, scraped by Prometheus every 30 seconds
  - Saturation metrics: `mereka_sli_redis_memory_utilization_ratio` from `redis_memory_used_bytes / redis_memory_max_bytes`
  - Error budget calculation: `mereka_sli_redis_error_budget_remaining_minutes = (30d * 24h * 60m * 0.0005) - total_downtime_minutes` (Tier 1 SLO: 99.95%)

  **Elasticsearch**
  - SLI metric name: `mereka_sli_elasticsearch_availability_ratio`
  - Calculation formula: Based on cluster health status (`green` = 1.0, `yellow` = 0.95, `red` = 0.0)
  - Data source: Elasticsearch exporter metrics, scraped by Prometheus every 30 seconds
  - Saturation metrics: `mereka_sli_elasticsearch_heap_utilization_ratio` from `elasticsearch_jvm_memory_used_bytes / elasticsearch_jvm_memory_max_bytes`
  - Error budget calculation: `mereka_sli_elasticsearch_error_budget_remaining_minutes = (30d * 24h * 60m * 0.001) - total_downtime_minutes` (Tier 2 SLO: 99.9%)

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

#### Error Budget Exhaustion Procedures

- The system MUST enforce the following procedures when error budget is exhausted or at risk:

  **Budget Exhaustion (< 0% remaining)**
  - The system MUST automatically trigger a P1 incident with title "Error Budget Exhausted: [Service]"
  - The system MUST immediately notify: on-call engineer (page), engineering lead (Slack + email), VP/CTO (email)
  - The system MUST freeze all non-incident-remediation deployments to the affected service
  - The engineering team MUST enter "Reliability Sprint" mode: all feature work paused, focus on reliability improvements
  - The system MUST schedule a post-incident review within 2 business days to identify root cause and prevention measures
  - The system MUST NOT reset the error budget -- it refills naturally as the 30-day rolling window advances
  - The reliability sprint MUST continue until error budget is restored to >= 10%

  **Budget Critical (< 10% remaining)**
  - The system MUST send daily Slack notifications to engineering channel with current budget status
  - The system MUST require VP/CTO approval for any non-critical deployment
  - The engineering lead MUST schedule a reliability review meeting within 3 business days
  - The system MUST prioritize bug fixes and stability improvements over new feature development
  - The system MUST produce a budget recovery plan documenting: root cause analysis, immediate mitigations, long-term improvements

  **Budget Warning (10-25% remaining)**
  - The system MUST require engineering lead + product approval for any deployment
  - The system MUST increase monitoring alert sensitivity for the affected service (lower thresholds)
  - The engineering lead MUST review recent incidents and identify patterns
  - The system MUST document mitigations in the weekly engineering sync

  **Budget Low (25-50% remaining)**
  - The system MUST require engineering lead approval for deployments
  - The system SHOULD trigger a proactive review of recent error trends
  - The system SHOULD increase deployment testing rigor (extended canary periods, more validation checks)

  **Budget Healthy (>= 50% remaining)**
  - Normal deployment process applies (automated CI/CD)
  - No special approvals required

  **Incident Remediation Exception**
  - Deployments that fix an active P1/P2 incident MUST be exempt from deployment freeze
  - The incident commander MUST document the exception: incident ID, deployment justification, rollback plan
  - The system MUST log the exception with structured fields: `{event: "deployment_freeze_override", reason: "incident_remediation", incident_id: "<id>", service: "<name>"}`

  **Budget Recovery Tracking**
  - The system MUST project error budget recovery time based on current burn rate
  - The system MUST display projected recovery date on the SLO dashboard
  - The system MUST send a notification when budget recovers to >= 25% (exits critical state)

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

#### SLA Breach Escalation Procedures

- The system MUST define and enforce the following procedures when an SLA breach occurs or is imminent:

  **SLA Breach Detection**
  - The system MUST detect an SLA breach when any service's actual availability falls below the SLA target for the rolling 30-day window
  - The system MUST detect an imminent SLA breach when projected availability (based on current burn rate) will fall below SLA target within 72 hours
  - The system MUST immediately notify: engineering lead, VP/CTO, account manager for affected enterprise clients
  - The system MUST automatically create a P1 incident with title "SLA Breach: [Service] - [Current Availability]"

  **Immediate Response (Within 1 hour of breach detection)**
  - Engineering lead MUST acknowledge the breach notification
  - Engineering lead MUST assemble an incident response team (minimum: 2 engineers + incident commander)
  - Incident commander MUST send initial notification to affected enterprise clients using the stakeholder communication template
  - The team MUST identify all contributing incidents within the 30-day window
  - The team MUST assess whether the breach is due to: single major incident, multiple smaller incidents, or chronic degradation

  **Client Communication Timeline**
  - **T+0 (Breach detection)**: Automated notification to internal stakeholders
  - **T+1 hour**: Initial notification to affected enterprise clients (acknowledgement of breach, investigation started)
  - **T+4 hours**: First detailed update to clients (preliminary root cause, remediation plan, timeline)
  - **T+24 hours**: Remediation status update (progress on fixes, updated timeline)
  - **T+5 business days**: Formal incident postmortem delivered to clients (full timeline, root cause, prevention measures)
  - **T+10 business days**: Remediation completion report (all prevention measures implemented, SLA compliance restored)

  **Remediation Requirements**
  - The team MUST produce a detailed remediation plan within 4 hours of breach detection
  - The remediation plan MUST include: root cause analysis, immediate fixes, long-term improvements, timeline for each
  - All P1/P2 incidents contributing to the breach MUST have postmortems published
  - The team MUST implement immediate mitigations within 24 hours to prevent further degradation
  - The team MUST implement long-term improvements within 30 days (or document alternative timeline with justification)

  **SLA Credit Calculation (If Contractual)**
  - The system MUST calculate service credits based on the severity of the breach:
    - Breach by 0.1-0.5%: [X]% service credit
    - Breach by 0.5-1.0%: [Y]% service credit
    - Breach by > 1.0%: [Z]% service credit
  - Service credits MUST be proposed to the client within 5 business days of breach confirmation
  - Service credits MUST be applied to the next billing cycle unless otherwise negotiated

  **Executive Review**
  - For any Tier 1 SLA breach, the VP/CTO MUST conduct an executive review within 5 business days
  - The executive review MUST assess: technical root cause, process failures, organizational gaps
  - The executive review MUST produce action items with owners and deadlines
  - The engineering lead MUST report on action item completion in the next monthly SLA report

  **Repeat Breach Escalation**
  - If the same service breaches SLA in 2 consecutive months, the system MUST escalate to VP/CTO and schedule an emergency architecture review
  - If the same service breaches SLA in 3 out of 6 months, the system MUST trigger a mandatory reliability sprint (minimum 2 weeks, all hands)
  - The reliability sprint MUST not end until the service achieves 2 consecutive weeks of SLO compliance

  **Client Relationship Management**
  - Account managers MUST schedule a 1-on-1 call with affected enterprise clients within 3 business days of breach
  - Account managers MUST offer additional support: dedicated technical account manager, increased monitoring, priority bug fixes
  - If a client experiences 2 SLA breaches in a quarter, the VP/CTO MUST personally contact the client executive sponsor

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

#### Synthetic Alert Delivery Drills

To ensure the alert delivery pipeline (Alertmanager → Slack/PagerDuty) remains operational, the system MUST perform regular synthetic drills:

**Weekly Drill Requirements**:
- The system MUST send a synthetic test alert every Monday at 09:00 UTC
- The synthetic alert MUST route through the production Alertmanager instance
- The synthetic alert MUST be delivered to the same channels as production alerts (Slack `#ops-alerts`, PagerDuty if configured)
- The synthetic alert MUST be clearly labeled as a drill (subject line: `[DRILL] Alert Delivery Test`)

**Drill Implementation**:
- The system MUST deploy a Kubernetes CronJob to generate synthetic alerts
- The CronJob MUST run in the `mereka-lms` namespace with label `app.kubernetes.io/name=synthetic-alert-drill`
- The drill script MUST POST to the Alertmanager API: `/api/v1/alerts` with a test alert payload
- The drill alert MUST have severity `info` to avoid triggering on-call pages

**Delivery Confirmation**:
- The system MUST log the delivery confirmation timestamp to Loki with structured fields:
  ```json
  {
    "event": "synthetic_alert_drill",
    "status": "success|failed",
    "delivery_timestamp": "<ISO8601>",
    "delivery_latency_ms": <N>,
    "channel": "slack|pagerduty"
  }
  ```
- The system SHOULD verify delivery by checking Slack API or PagerDuty API for the drill message

**Missed Drill Handling**:
- If a synthetic alert drill fails to deliver within 5 minutes, the system MUST trigger a REAL P2 alert
- The real alert MUST page the on-call engineer with subject: `Alert Delivery Pipeline Failure - Drill Not Received`
- The real alert MUST include: expected drill time, delivery status check results, runbook link
- The system MUST NOT suppress missed-drill alerts (no silencing/inhibition rules)

**Drill Verification**:
- The system MUST track drill success rate as a metric: `mereka_alerting_drill_success_total` (counter)
- The system MUST track drill delivery latency: `mereka_alerting_drill_latency_seconds` (histogram)
- The system SHOULD display drill health on the SLO dashboard (panel: "Alert Delivery Drills - Last 30 Days")

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

#### Reporting Templates

- The system MUST use the following standardized templates for SLA reporting:

  **Monthly SLA Compliance Report Template**

  ```markdown
  # Mereka Academy - Monthly SLA Compliance Report
  **Reporting Period**: [Month Year] ([YYYY-MM-01] to [YYYY-MM-DD])
  **Report Generated**: [ISO8601 timestamp]
  **Report Version**: 1.0

  ## Executive Summary
  - Overall Platform Availability: [XX.XX]%
  - SLA Compliance Status: [PASS/FAIL]
  - Critical Incidents (P1): [N]
  - Maintenance Windows: [N]
  - Error Budget Status: [Healthy/Low/Critical/Exhausted]

  ## Service-Level Metrics

  ### Tier 1: Critical Services
  | Service | SLO Target | Actual | SLA Target | Status | Error Budget Remaining |
  |---------|-----------|--------|-----------|--------|----------------------|
  | LMS | 99.95% | [XX.XX]% | 99.9% | [PASS/FAIL] | [XX.X] minutes |
  | CMS | 99.95% | [XX.XX]% | 99.9% | [PASS/FAIL] | [XX.X] minutes |
  | MySQL | 99.95% | [XX.XX]% | 99.9% | [PASS/FAIL] | [XX.X] minutes |
  | Redis | 99.95% | [XX.XX]% | 99.9% | [PASS/FAIL] | [XX.X] minutes |
  | Caddy | 99.95% | [XX.XX]% | 99.9% | [PASS/FAIL] | [XX.X] minutes |

  ### Tier 2: Important Services
  | Service | SLO Target | Actual | SLA Target | Status | Error Budget Remaining |
  |---------|-----------|--------|-----------|--------|----------------------|
  | MFE | 99.9% | [XX.XX]% | 99.5% | [PASS/FAIL] | [XX.X] minutes |
  | Forum | 99.9% | [XX.XX]% | 99.5% | [PASS/FAIL] | [XX.X] minutes |
  | Discovery | 99.9% | [XX.XX]% | 99.5% | [PASS/FAIL] | [XX.X] minutes |
  | Ecommerce | 99.9% | [XX.XX]% | 99.5% | [PASS/FAIL] | [XX.X] minutes |
  | Workers | 99.9% | [XX.XX]% | 99.5% | [PASS/FAIL] | [XX.X] minutes |

  ### Tier 3: Optional Services
  | Service | SLO Target | Actual | SLA Target | Status | Error Budget Remaining |
  |---------|-----------|--------|-----------|--------|----------------------|
  | Notes | 99.5% | [XX.XX]% | 99.0% | [PASS/FAIL] | [XX.X] hours |
  | XQueue | 99.5% | [XX.XX]% | 99.0% | [PASS/FAIL] | [XX.X] hours |

  ## Latency Performance

  | Service | Endpoint Category | p50 Target | p50 Actual | p95 Target | p95 Actual | p99 Target | p99 Actual | Status |
  |---------|------------------|-----------|-----------|-----------|-----------|-----------|-----------|--------|
  | LMS | Page loads | 500ms | [XXX]ms | 2,000ms | [XXX]ms | 5,000ms | [XXX]ms | [PASS/FAIL] |
  | CMS | Page loads | 800ms | [XXX]ms | 3,000ms | [XXX]ms | 8,000ms | [XXX]ms | [PASS/FAIL] |
  | MFE | Page loads | 300ms | [XXX]ms | 1,000ms | [XXX]ms | 3,000ms | [XXX]ms | [PASS/FAIL] |
  | API | REST endpoints | 200ms | [XXX]ms | 800ms | [XXX]ms | 2,000ms | [XXX]ms | [PASS/FAIL] |

  ## Incident Summary

  | Severity | Count | Total Duration | MTTR (Mean Time to Resolve) | Availability Impact |
  |----------|-------|---------------|---------------------------|-------------------|
  | P1 (Critical) | [N] | [XX] hours [YY] minutes | [XX] minutes | [XX.XX]% |
  | P2 (High) | [N] | [XX] hours [YY] minutes | [XX] minutes | [XX.XX]% |
  | P3 (Medium) | [N] | [XX] hours [YY] minutes | [XX] minutes | [XX.XX]% |
  | P4 (Low) | [N] | N/A | N/A | 0.00% |

  ### Top Incidents by Impact
  1. [Incident ID]: [Brief description] - Duration: [XX] min - Impact: [XX.XX]%
  2. [Incident ID]: [Brief description] - Duration: [XX] min - Impact: [XX.XX]%
  3. [Incident ID]: [Brief description] - Duration: [XX] min - Impact: [XX.XX]%

  ## Maintenance Windows

  | Date | Start Time (UTC) | End Time (UTC) | Duration | Scope | Outcome |
  |------|-----------------|----------------|----------|-------|---------|
  | [YYYY-MM-DD] | [HH:MM] | [HH:MM] | [XX] minutes | [Description] | [Successful/Overrun/Cancelled] |

  ## Error Budget Consumption

  | Service | Budget Start | Budget Consumed | Budget Remaining | Burn Rate Trend |
  |---------|-------------|----------------|-----------------|----------------|
  | LMS | 21.6 min | [XX.X] min | [XX.X] min | [Increasing/Stable/Decreasing] |
  | CMS | 21.6 min | [XX.X] min | [XX.X] min | [Increasing/Stable/Decreasing] |
  | MFE | 43.8 min | [XX.X] min | [XX.X] min | [Increasing/Stable/Decreasing] |

  ## Trend Comparison (vs Previous Month)

  - Overall availability: [XX.XX]% ([+/- X.XX]% change)
  - Total incidents: [N] ([+/- N] change)
  - Mean time to resolve (P1/P2): [XX] minutes ([+/- XX] minutes change)
  - Error budget consumption rate: [XX]% of monthly budget ([+/- XX]% change)

  ## Recommendations
  - [Action item based on observed trends]
  - [Action item based on observed trends]
  - [Action item based on observed trends]

  ## Appendix
  - Full incident log: [Link to sanitized incident log]
  - Detailed metrics: [Link to Grafana dashboard snapshot]
  - Methodology: [Link to this spec document]
  ```

  **Quarterly SLA Compliance Report Template**

  ```markdown
  # Mereka Academy - Quarterly SLA Compliance Report
  **Reporting Period**: [Quarter] [Year] ([YYYY-MM-DD] to [YYYY-MM-DD])
  **Report Generated**: [ISO8601 timestamp]
  **Report Version**: 1.0

  ## Executive Summary
  - Overall Platform Availability (90-day): [XX.XX]%
  - SLA Compliance Status: [PASS/FAIL]
  - Total Incidents (P1/P2): [N]
  - Total Maintenance Windows: [N]
  - Error Budget Health Trend: [Improving/Stable/Declining]

  ## 90-Day Availability Trend

  | Service | Month 1 | Month 2 | Month 3 | Q Average | SLA Target | Status |
  |---------|---------|---------|---------|-----------|-----------|--------|
  | LMS | [XX.XX]% | [XX.XX]% | [XX.XX]% | [XX.XX]% | 99.9% | [PASS/FAIL] |
  | CMS | [XX.XX]% | [XX.XX]% | [XX.XX]% | [XX.XX]% | 99.9% | [PASS/FAIL] |
  | MFE | [XX.XX]% | [XX.XX]% | [XX.XX]% | [XX.XX]% | 99.5% | [PASS/FAIL] |

  ## Performance Regression Summary

  | Date | Service | Regression Type | Duration | Root Cause | Resolution |
  |------|---------|----------------|----------|-----------|------------|
  | [YYYY-MM-DD] | [Service] | Latency spike | [XX] min | [Brief cause] | [Brief resolution] |
  | [YYYY-MM-DD] | [Service] | Error rate spike | [XX] min | [Brief cause] | [Brief resolution] |

  ## Capacity Planning Recommendations

  ### Infrastructure Saturation Trends
  - MySQL connection utilization: [XX]% average ([+/- X]% vs prev quarter)
  - Redis memory utilization: [XX]% average ([+/- X]% vs prev quarter)
  - LMS/CMS CPU utilization: [XX]% average ([+/- X]% vs prev quarter)

  ### Scaling Recommendations
  1. [Recommendation based on saturation trends]
  2. [Recommendation based on saturation trends]
  3. [Recommendation based on saturation trends]

  ## On-Call Health Metrics

  | Metric | Q1 | Q2 | Q3 | Q4 | Trend |
  |--------|----|----|----|----|-------|
  | Total alerts | [N] | [N] | [N] | [N] | [Up/Down/Stable] |
  | After-hours pages | [N] | [N] | [N] | [N] | [Up/Down/Stable] |
  | Escalations to L2 | [N] | [N] | [N] | [N] | [Up/Down/Stable] |
  | Mean time to acknowledge (P1) | [XX] min | [XX] min | [XX] min | [XX] min | [Up/Down/Stable] |

  ## SLO Target Adjustment Recommendations

  | Service | Current SLO | Current SLA | Observed Reliability | Recommendation | Justification |
  |---------|------------|-------------|---------------------|---------------|---------------|
  | [Service] | [XX.XX]% | [XX.XX]% | [XX.XX]% | [Maintain/Tighten/Loosen] | [Brief justification] |

  ## Quarterly Business Review Topics
  1. Platform reliability summary
  2. Key incidents and learnings
  3. Capacity planning and scaling roadmap
  4. SLO target discussions and adjustments
  5. Next quarter reliability focus areas

  ## Appendix
  - Monthly reports: [Links to 3 monthly reports]
  - Detailed incident postmortems: [Links to P1/P2 postmortems]
  - Grafana dashboard snapshots: [Links]
  ```

  **Stakeholder Communication Template (Incident)**

  ```markdown
  **Subject**: [Platform Status] [Service] - [Severity] Incident [ID]

  **Status**: [Investigating/Identified/Monitoring/Resolved]
  **Severity**: [P1/P2/P3]
  **Impact**: [Brief description of user impact]
  **Started**: [ISO8601 timestamp]
  **Last Update**: [ISO8601 timestamp]

  ## Current Status
  [Brief description of current state]

  ## Impact
  - Affected services: [List]
  - Affected users: [Scope - all users / specific tenant / subset]
  - Functionality impact: [What users cannot do]

  ## Timeline
  - [HH:MM UTC]: [Event description]
  - [HH:MM UTC]: [Event description]
  - [HH:MM UTC]: [Event description]

  ## Next Steps
  - [Action being taken]
  - [Estimated time to next update]

  ## Contact
  For questions, contact: [support email]
  Status page: https://status.mereka.dev
  ```

  **Stakeholder Communication Template (Maintenance Window)**

  ```markdown
  **Subject**: [Scheduled Maintenance] Mereka Academy - [YYYY-MM-DD]

  **Maintenance Window**: [YYYY-MM-DD HH:MM UTC] to [YYYY-MM-DD HH:MM UTC] (approximately [N] hours)
  **Impact**: [Expected service availability during maintenance]
  **Notification Date**: [YYYY-MM-DD] ([N] hours advance notice)

  ## Purpose
  [Brief description of maintenance purpose - e.g., database upgrade, security patching, infrastructure scaling]

  ## Expected Impact
  - Platform availability: [Full outage / Partial degradation / No downtime expected]
  - Affected services: [List]
  - User experience: [What users will experience]

  ## Preparation
  - We recommend: [Any user actions recommended before maintenance]
  - Please save any work in progress before the maintenance window

  ## Communication Plan
  - 15 minutes before start: Status page updated to "maintenance in progress"
  - During maintenance: Updates every 30 minutes on status page
  - Upon completion: Final status update and confirmation of service restoration

  ## Rollback Plan
  If issues arise, we will: [Brief description of rollback procedure]

  ## Contact
  For questions before the maintenance window: [support email]
  Status page: https://status.mereka.dev
  ```

### Non-Functional Requirements

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

### Synthetic Alert Drills

- [ ] AC-DRILL-001: Given the synthetic alert drill CronJob is deployed, when `kubectl get cronjob -n mereka-lms synthetic-alert-drill` is run, then the CronJob exists with schedule `0 9 * * 1` (every Monday at 09:00 UTC)
- [ ] AC-DRILL-002: Given a drill execution, when the drill script runs, then it POSTs to Alertmanager API `/api/v1/alerts` with a test alert labeled `[DRILL] Alert Delivery Test`
- [ ] AC-DRILL-003: Given a successful drill, when the drill completes, then a structured log entry is written to Loki with `event=synthetic_alert_drill`, `status=success`, and `delivery_timestamp`
- [ ] AC-DRILL-004: Given drill metrics are exposed, when Prometheus queries `mereka_alerting_drill_success_total`, then a counter value is returned showing cumulative drill successes
- [ ] AC-DRILL-005: Given a missed drill (no delivery within 5 minutes), when the watchdog timer expires, then a REAL P2 alert is triggered with subject `Alert Delivery Pipeline Failure - Drill Not Received`
- [ ] AC-DRILL-006: Given the SLO dashboard, when viewing the "Alert Delivery Drills - Last 30 Days" panel, then drill success/failure history is visible as a time series
- [ ] AC-DRILL-007: Given the drill alert is sent to Slack, when checking the `#ops-alerts` channel, then the drill message appears within 2 minutes with clear `[DRILL]` prefix

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
- [ ] AC-024: Given a quarterly reporting period, when the quarterly SLA report is generated, then it contains 90-day availability trends, performance regression summary, capacity planning recommendations, and on-call health metrics
- [ ] AC-025: Given an enterprise client, when the monthly SLA report is distributed, then it is delivered within 5 business days of month end using the standardized report template

### Service-Specific SLIs

- [ ] AC-026: Given LMS is operational, when Prometheus queries `mereka_sli_lms_availability_ratio`, then a value between 0 and 1 is returned representing current availability
- [ ] AC-027: Given CMS is operational, when Prometheus queries `mereka_sli_cms_latency_p95_seconds`, then a value in seconds is returned representing p95 latency
- [ ] AC-028: Given all production services, when Prometheus recording rules are evaluated, then each service has corresponding `mereka_sli_<service>_availability_ratio` and `mereka_sli_<service>_error_budget_remaining_minutes` metrics

### Error Budget Procedures

- [ ] AC-029: Given error budget is exhausted (< 0%), when the exhaustion is detected, then a P1 incident is created, deployments are frozen (except remediation), and engineering lead + VP/CTO are notified within 15 minutes
- [ ] AC-030: Given error budget is critical (< 10%), when deployment is attempted, then VP/CTO approval is required and the gate check blocks deployment until approval is documented
- [ ] AC-031: Given error budget is exhausted, when the reliability sprint begins, then all feature work is paused and the team focuses exclusively on reliability improvements until budget is restored to >= 10%
- [ ] AC-032: Given error budget consumption, when the SLO dashboard is viewed, then projected recovery date is displayed based on current burn rate

### SLA Breach Procedures

- [ ] AC-033: Given an SLA breach is detected, when the breach notification fires, then engineering lead, VP/CTO, and affected enterprise account managers are notified within 1 hour
- [ ] AC-034: Given an SLA breach, when client communication begins, then the first notification is sent within 1 hour, a detailed update within 4 hours, and a formal postmortem within 5 business days
- [ ] AC-035: Given an SLA breach, when remediation plan is created, then it includes root cause analysis, immediate fixes, long-term improvements, and timeline for each, documented within 4 hours of breach detection
- [ ] AC-036: Given a Tier 1 service breaches SLA in 2 consecutive months, when the second breach is confirmed, then an emergency architecture review is automatically scheduled

### SLO Dashboard

- [ ] AC-037: Given the Open edX SLO dashboard exists at `infrastructure/monitoring/dashboards/openedx-slo-dashboard.json`, when it is deployed to GCP Monitoring, then it displays all Tier 1 SLO metrics (LMS availability, CMS availability, latency P99/P95/P50, error rates, error budget)
- [ ] AC-038: Given the SLO dashboard, when viewed, then it includes a service ownership panel displaying: primary owner, service tier, on-call rotation structure, and escalation contacts (L1 through L4)
- [ ] AC-039: Given the SLO dashboard, when viewed, then it includes direct links to PrometheusRule definitions in `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`
- [ ] AC-040: Given the SLO dashboard, when viewed, then it includes links to operational runbooks: On-Call Observability Playbook, SLO/SLA Spec, Deployment Runbook, and Troubleshooting Guide
- [ ] AC-041: Given the SLO dashboard, when error budget panels are displayed, then they use color thresholds: RED (< 10% or exhausted), YELLOW (10-25%), GREEN (>= 25%)

### Additional Edge Cases

- [ ] AC-042: Given GCP uptime checks from multiple regions, when latency is measured for SLA purposes, then only the Asia-Pacific regional probe is used as the authoritative measurement
- [ ] AC-043: Given a MySQL infrastructure failure causes LMS, CMS, and Forum to fail simultaneously, when error budgets are calculated, then downtime is attributed to MySQL only and dependent services' budgets are not consumed if they recover immediately after MySQL
- [ ] AC-044: Given a maintenance window notification email fails to send, when the failure is detected, then operations is alerted within 1 hour and manual client outreach is triggered
- [ ] AC-045: Given a rolling deployment causes transient 503 errors, when errors are < 0.1% of traffic and last < 1 minute, then they may be excluded from SLO calculation if documented in monthly report
- [ ] AC-046: Given timestamp discrepancies between Prometheus and GCP Monitoring, when SLA is calculated, then the time measurement most favorable to the client is used

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

### Multi-Region Latency Measurement

**Symptom**: GCP uptime checks from different regions show inconsistent latency (Singapore probe shows 100ms, US probe shows 3000ms).

**Cause**: The platform is deployed in `asia-southeast1` -- latency for probes from distant regions includes intercontinental network transit.

**Mitigation**:
- The system MUST use the regional probe closest to the deployment (Singapore/Asia region) as the authoritative latency measurement for SLA purposes
- The system MUST document in SLA contracts that latency targets apply to Asia-Pacific region access only
- The system SHOULD track latency from multiple regions for capacity planning but NOT count non-regional probes against SLA
- If clients are primarily in a specific geography (e.g., Malaysia, Singapore, Indonesia), the system MUST configure GCP uptime checks to probe from those specific locations
- For global clients, the system MUST negotiate separate regional latency targets in the SLA (e.g., < 2s p95 in APAC, < 5s p95 in EMEA/Americas)

### Cascading Failure SLO Impact

**Symptom**: MySQL goes down (Tier 1 service), causing LMS, CMS, Forum, Ecommerce to all fail simultaneously. All services breach SLO in the same window.

**Cause**: Shared infrastructure failure creates correlated unavailability across dependent services.

**Mitigation**:
- The system MUST track infrastructure-level incidents separately from service-level incidents
- When a Tier 1 infrastructure service (MySQL, Redis) fails, the system MUST attribute downtime to the infrastructure service only, not to all dependent services
- The error budget for dependent services SHOULD NOT be consumed during an infrastructure-wide outage IF the dependent services resume normal operation immediately after infrastructure recovery
- The system MUST document infrastructure dependencies in each service's SLO definition
- The system MUST calculate "attributable downtime" for each service: total downtime MINUS downtime during infrastructure-wide incidents where the service had no independent failures
- For SLA reporting, if an infrastructure failure causes multi-service outages, the report MUST clearly state: "All service downtime attributed to MySQL outage on [date]" rather than treating each service as independently failing
- If a service experiences cascading failures due to insufficient retry/circuit-breaker logic (fails even after infrastructure recovers), the downtime MUST count against that service's error budget

### Maintenance Window Notification Failure

**Symptom**: Maintenance window is scheduled and declared, but notification email to enterprise clients fails to send due to email service issue.

**Cause**: Dependency on external email delivery service (SendGrid, SES, etc.).

**Mitigation**:
- The system MUST use multiple notification channels for maintenance announcements: email (primary), status page update (mandatory), Slack notification (for internally-managed clients), SMS (for P1-tier clients)
- The system MUST verify email delivery via delivery receipts or API confirmation
- If email notification fails, the system MUST alert operations within 1 hour and trigger manual outreach to affected clients
- The system MUST maintain a maintenance calendar on the status page (https://status.mereka.dev) as a backup notification mechanism
- If notification fails and the maintenance window is within 72 hours, the system MUST consider rescheduling the maintenance to meet the 72-hour advance notice requirement
- The system MUST log all notification attempts with delivery status in a structured format

### SLO Measurement During Deployment

**Symptom**: During a rolling deployment, 10% of requests go to pods that are still starting up (readiness probe not yet passing), causing transient 503 errors.

**Cause**: Kubernetes routes traffic to pods before application is fully ready.

**Mitigation**:
- The system MUST configure readiness probes for all services to ensure pods only receive traffic when fully operational
- The system MUST use preStop lifecycle hooks to gracefully drain connections before pod termination
- The system MUST configure appropriate readiness probe settings: `initialDelaySeconds`, `periodSeconds`, `failureThreshold`
- If deployment-related errors (503 from not-ready pods) occur, the system SHOULD NOT count them against availability SLO IF they are below 0.1% of total traffic
- The system MUST monitor deployment success rate as a separate metric: `mereka_deployment_errors_total` (errors caused by deployment process itself)
- For SLA reporting, deployment-related transient errors (< 1 minute duration, < 0.1% traffic impact) MAY be excluded if documented in the monthly report
- If deployment-related errors exceed 0.1% of traffic or last > 1 minute, they MUST count fully against SLO

### Clock Skew and Timestamp Inconsistencies

**Symptom**: Prometheus shows an incident lasted 10 minutes, but GCP Cloud Monitoring shows 15 minutes, leading to SLA calculation discrepancies.

**Cause**: Clock skew between Prometheus server, GCP infrastructure, and application pods.

**Mitigation**:
- The system MUST ensure all infrastructure uses NTP for time synchronization (GKE nodes sync automatically)
- The system MUST use consistent time sources for SLI calculation (prefer Prometheus as single source of truth for internal SLOs, GCP Cloud Monitoring for external SLAs)
- When discrepancies exist, the system MUST use the time measurement most favorable to the client for SLA purposes (longer uptime / shorter downtime)
- The system MUST document the authoritative time source for each SLI in this spec
- The system MUST alert if clock skew > 5 seconds is detected between Prometheus and GCP Monitoring
- For incident postmortems, all timestamps MUST be normalized to UTC and sourced from a single system (Prometheus preferred)

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
| `SLOBudgetCritical` | P1 | Error budget remaining < 10% for any Tier 1 service | Page primary on-call; email VP/CTO |
| `LatencyRegressionSpike` | P2 | p95 latency > 2x 7-day baseline for 15 minutes | Page primary on-call |
| `LatencyRegressionDrift` | P3 | p95 latency > 1.5x 7-day baseline for 1 hour | Slack engineering channel |
| `ErrorRateSpike` | P1 | 5xx error rate > 3x 7-day average for 10 minutes | Page primary + secondary on-call |
| `SLIMeasurementDown` | P2 | No SLI data for any Tier 1 service for 10 minutes | Page primary on-call |
| `MaintenanceWindowOverrun` | P3 | Maintenance window has reached 75% of declared duration | Slack operations channel |
| `SLABreachImminent` | P1 | Projected 30-day availability will breach SLA within 72 hours at current burn rate | Page primary + secondary on-call; notify engineering lead |
| `SLABreachConfirmed` | P1 | Actual 30-day availability has fallen below SLA target | Page all on-call; notify VP/CTO; create incident |
| `ErrorBudgetRecoveryStalled` | P2 | Error budget < 25% for > 7 days with no recovery trend | Slack engineering channel; email engineering lead |

**Alert Configuration Details**:

- All SLO/SLA alerts MUST use multi-window burn rate calculations to reduce false positives:
  - Fast burn window: 1 hour (detects rapid degradation)
  - Slow burn window: 6 hours (detects gradual degradation)
  - Alert fires only when BOTH windows exceed threshold simultaneously

- Burn rate thresholds are calculated as multiples of the "normal" budget consumption rate:
  - 1x burn rate = consuming error budget at exactly the rate that would exhaust it in 30 days
  - 14.4x burn rate = consuming budget 14.4 times faster (would exhaust in ~2 days)
  - 6x burn rate = consuming budget 6 times faster (would exhaust in ~5 days)

- All alerts MUST include the following annotations:
  - `summary`: Brief description of the alert
  - `description`: Detailed explanation including current metric value, threshold, and affected service
  - `runbook`: Link to runbook for this alert type (e.g., `docs/operations/runbooks/slo-budget-exhausted.md`)
  - `dashboard`: Link to relevant Grafana dashboard for investigation
  - `service`: Affected service name
  - `tier`: Service tier (1, 2, or 3)
  - `current_value`: Current metric value that triggered the alert
  - `threshold`: Threshold that was exceeded

### Dashboards

The system MUST create or update the following Grafana dashboards:

| Dashboard | UID | Panels |
|-----------|-----|--------|
| `Mereka LMS - SLO Overview` | `mereka-slo-overview` | Per-service availability (30-day rolling), error budget remaining (bar chart), burn rate trend (time series), latency percentiles by endpoint category, deployment annotations, maintenance window markers |
| `Mereka LMS - SLO Detail` (per service) | `mereka-slo-detail-{service}` | Individual service deep-dive: availability ratio, error budget burn-down, latency histogram heatmap, error rate trend, saturation metrics, top slow endpoints |
| `Mereka LMS - Error Budget` | `mereka-error-budget` | Budget remaining per tier (gauge), budget consumption timeline (stacked area), deployment freeze status (indicator), budget forecast (when budget hits zero at current burn rate) |
| `Mereka LMS - SLA Compliance` | `mereka-sla-compliance` | SLA pass/fail status per service, days until next SLA breach at current burn rate, historical SLA compliance trend, incident impact summary |

**Dashboard Panel Specifications**:

**SLO Overview Dashboard** (`mereka-slo-overview`):
1. **Service Availability Grid** (Stat panels)
   - One panel per service showing current 30-day availability as percentage
   - Color thresholds: Green (>= SLO target), Yellow (SLO target to SLA target), Red (< SLA target)
   - Sparkline showing 7-day trend
   - Drill-down link to service detail dashboard

2. **Error Budget Status** (Bar gauge)
   - Horizontal bar per service showing error budget remaining as percentage
   - Color thresholds: Green (>= 50%), Yellow (25-50%), Orange (10-25%), Red (< 10%)
   - Absolute minutes remaining displayed as text overlay

3. **Burn Rate Trend** (Time series)
   - Multi-line chart showing 1h and 6h burn rates for all Tier 1 services
   - Horizontal threshold lines at 14.4x, 6x, 3x, 1x burn rate
   - Annotations for deployment events
   - Tooltips showing projected time to budget exhaustion

4. **Latency Heatmap** (Heatmap)
   - X-axis: Time (last 7 days)
   - Y-axis: Service + endpoint category
   - Color: p95 latency (green = within target, red = exceeding target)
   - Allows quick identification of latency regressions

5. **Incident Impact Timeline** (Time series with annotations)
   - Shows platform-wide availability over last 30 days
   - Annotations for each P1/P2 incident with duration and impact
   - Maintenance windows shown as vertical shaded regions
   - Deployment events shown as vertical markers

6. **Deployment Freeze Status** (Stat panel)
   - Current deployment policy based on error budget: Normal / Cautious / Restricted / Frozen
   - Color: Green (Normal), Yellow (Cautious), Orange (Restricted), Red (Frozen)

**SLO Detail Dashboard** (per service, e.g., `mereka-slo-detail-lms`):
1. **Availability Gauge** (Gauge)
   - Current 30-day availability
   - Thresholds: SLO target, SLA target

2. **Error Budget Burn-Down** (Time series)
   - Line chart showing error budget remaining over last 30 days
   - Projected trend line based on current burn rate
   - Shaded regions for budget health zones

3. **Request Rate** (Time series)
   - Total requests per second
   - Successful (2xx/3xx) vs failed (5xx) split

4. **Latency Distribution** (Time series)
   - Multi-line: p50, p75, p95, p99
   - Horizontal lines for latency targets
   - Deployment annotations

5. **Error Rate** (Time series)
   - 5xx error rate as percentage
   - 5-minute rolling window
   - Threshold lines for Warning and Critical

6. **Top Slow Endpoints** (Table)
   - Endpoint path, p95 latency, request count, error rate
   - Sortable by latency
   - Links to trace search in Tempo

7. **Saturation Metrics** (Gauge panels)
   - CPU utilization, memory utilization, connection pool usage
   - Pod count and restart count

**Error Budget Dashboard** (`mereka-error-budget`):
1. **Budget Remaining by Tier** (Bar gauge)
   - Grouped by tier (Tier 1, Tier 2, Tier 3)
   - Shows absolute minutes remaining per service

2. **Budget Consumption Timeline** (Stacked area chart)
   - X-axis: Last 30 days
   - Y-axis: Error budget consumed (minutes)
   - Stack: Per-service contribution
   - Allows identification of which services are consuming budget fastest

3. **Deployment Freeze Indicator** (Stat panel)
   - Current freeze status with color coding
   - Time since last deployment
   - Next allowed deployment window

4. **Budget Forecast** (Time series with projection)
   - Historical budget trend
   - Projected trend based on current burn rate
   - Estimated date when budget hits critical thresholds (25%, 10%, 0%)

5. **Budget Policy Table** (Table)
   - Service, current budget %, policy tier, approvals required, last deployment
   - Color-coded by policy tier

**SLA Compliance Dashboard** (`mereka-sla-compliance`):
1. **SLA Pass/Fail Matrix** (Table)
   - Service, SLA Target, Current Availability, Status (PASS/FAIL), Margin
   - Color-coded rows (green = pass, red = fail)

2. **Days to SLA Breach** (Stat panels)
   - Per-service countdown: "X days until SLA breach at current burn rate"
   - Shows "N/A" if currently passing with healthy margin

3. **Historical SLA Compliance** (Time series)
   - Rolling 30-day availability per service over last 180 days
   - Horizontal line for SLA target
   - Shaded regions where SLA was breached

4. **Incident Impact Breakdown** (Pie chart)
   - Percentage of total downtime attributed to: P1 incidents, P2 incidents, maintenance windows, infrastructure failures

5. **Client-Facing Status** (Stat panel)
   - "Platform SLA Status: COMPLIANT" or "Platform SLA Status: BREACH"
   - Suitable for display on client-facing status page

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
