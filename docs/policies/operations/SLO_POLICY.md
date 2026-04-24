# SLO Policy — Mereka Academy
_Audience: Engineering + SRE • Owner: Engineering Lead • Last updated: 2026-02-25_

## Service Tiers

| Tier | Availability SLO | Error Budget (30 days) | Example Services |
|------|-----------------|----------------------|------------------|
| 1    | 99.95%          | 21.6 min             | LMS, Purchase Gateway |
| 2    | 99.5%           | 3.6 hours            | Studio/CMS, MFE |
| 3    | 99.0%           | 7.3 hours            | Forum (in-LMS) |

---

## SLI Definitions

SLIs are measured from django-prometheus / FastAPI prometheus instrumentation. 4xx responses are
excluded from availability denominators — they represent client errors, not platform failures.

### LMS (Tier 1)

| SLI | Definition | Target |
|-----|-----------|--------|
| Availability | `1 - (5xx_rate / non_4xx_rate)` over 30d | ≥ 99.95% |
| Latency p99 | `histogram_quantile(0.99, lms-metrics)` | < 2 s |
| Latency p95 | `histogram_quantile(0.95, lms-metrics)` | < 1 s |
| Error budget | `(1 - availability) / 0.0005` | ≤ 1× burn |

Prometheus job: `lms-metrics`

### Studio / CMS (Tier 2)

| SLI | Definition | Target |
|-----|-----------|--------|
| Availability | `1 - (5xx_rate / non_4xx_rate)` over 30d | ≥ 99.5% |
| Latency p99 | `histogram_quantile(0.99, cms-metrics)` | < 3 s |
| Error budget | `(1 - availability) / 0.005` | ≤ 1× burn |

Prometheus job: `cms-metrics`

### MFE / Caddy (Tier 2)

MFE SLI is measured at the Caddy ingress layer. Availability = HTTP 200–399 / total non-4xx
responses. Caddy exposes `caddy_http_requests_total` with `code` labels.

| SLI | Definition | Target |
|-----|-----------|--------|
| Availability | `1 - (5xx_rate / non_4xx_rate)` over 30d | ≥ 99.5% |
| Latency p95 | `histogram_quantile(0.95, caddy-metrics)` | < 500 ms |
| Error budget | `(1 - availability) / 0.005` | ≤ 1× burn |

Prometheus job: `caddy-metrics`

### Purchase Gateway (Tier 1)

Purchase Gateway is a FastAPI service instrumented via `prometheus-fastapi-instrumentator`.
Payment failures are treated as Tier 1 — any 5xx on `/payments/` or `/webhooks/` is a
direct revenue impact.

| SLI | Definition | Target |
|-----|-----------|--------|
| Availability | `1 - (5xx_rate / non_4xx_rate)` over 30d | ≥ 99.95% |
| Latency p99 | `histogram_quantile(0.99, purchase-gateway-metrics)` | < 1 s |
| Error budget | `(1 - availability) / 0.0005` | ≤ 1× burn |

Prometheus job: `purchase-gateway-metrics`

### Forum (Tier 3)

Forum runs in-process with the LMS (Python openedx-forum). Its SLI is measured via
LMS-level `django-prometheus` response metrics scoped to `/forum/` path prefix.

| SLI | Definition | Target |
|-----|-----------|--------|
| Availability | `1 - (5xx_rate / non_4xx_rate)` over 30d | ≥ 99.0% |
| Latency p95 | `histogram_quantile(0.95, lms-metrics, view=~"forum.*")` | < 2 s |
| Error budget | `(1 - availability) / 0.01` | ≤ 1× burn |

Prometheus job: `lms-metrics` (filtered by `view=~"forum.*"`)

---

## Error Budget Policy

### Normal (budget > 50%)
- All deployments proceed per standard release process
- No restrictions

### Caution (25%–50% remaining)
- P2 alert fires → SRE notified
- Non-critical feature deployments require tech lead approval
- Weekly budget review added to stand-up

### Restricted (< 25% remaining)
- P2 page → on-call SRE
- Only critical bug fixes may deploy
- All deployments require sign-off from Engineering Lead
- Daily budget review

### Exhausted (0% remaining)
- P1 page → on-call SRE + Engineering Lead
- Deployment freeze: no feature work deploys until budget recovers to ≥ 10%
- Reliability sprint activated: team focuses exclusively on error-rate reduction
- Executive notification within 1 business hour

Current execution boundary:

- use [../../ops/runbooks/POST_DEPLOY_GATE.md](../../ops/runbooks/POST_DEPLOY_GATE.md)
  for release blocking, exception handling, and post-deploy control flow
- do not assume a separate exhausted-budget runbook exists on this rebased
  branch unless a distinct operator workflow is later justified

---

## Burn-Rate Alert Thresholds

Multi-window burn-rate alerting per Google SRE Workbook §6.

| Window Pair | Burn Rate | Budget Consumed In | Severity | Action |
|------------|-----------|-------------------|----------|--------|
| 1h + 5m    | > 14.4×   | ~2 hours          | Critical (P1) | Page on-call immediately |
| 6h + 30m   | > 6×      | ~5 days           | Warning (P2) | Create incident ticket |
| 3d + 6h    | > 1×      | 30 days (all)     | Warning (P3) | Weekly review |

**Tier-specific error budget denominators:**

| Tier | SLO | Error Budget Rate | 14.4× threshold | 6× threshold |
|------|-----|------------------|-----------------|--------------|
| 1 (99.95%) | 0.05% budget | 0.0005 | `burn_rate > 14.4` | `burn_rate > 6` |
| 2 (99.5%)  | 0.5% budget  | 0.005  | `burn_rate > 14.4` | `burn_rate > 6` |
| 3 (99.0%)  | 1.0% budget  | 0.01   | `burn_rate > 14.4` | `burn_rate > 6` |

All alerts defined in:
- `deploy/k8s/base/monitoring/prometheusrule-slo.yaml` (LMS, CMS)
- `deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml` (MFE, Purchase Gateway, Forum)

---

## Review Cadence

| Review | Frequency | Owner | Output |
|--------|-----------|-------|--------|
| Error budget status | Monthly | Engineering Lead | Budget consumed vs. remaining |
| SLO compliance | Monthly | SRE | PASS/FAIL per service vs. target |
| SLO target adjustment | Quarterly | Engineering Lead + PM | Updated targets if baseline shifts |
| Policy review | Annually | CTO | Full policy refresh |

Monthly reports generated by: `./scripts/qa/generate-sla-report.sh`

---

## Alerting Destinations

| Severity | Channel | Escalation Path |
|----------|---------|-----------------|
| Critical (P1) | Slack `#mereka-oncall` + PagerDuty | On-call SRE → Engineering Lead (15 min) |
| Warning (P2)  | Slack `#mereka-operations` | SRE reviews within 2 hours |
| Warning (P3)  | Slack `#mereka-slo-digest` | Weekly review agenda |

Alertmanager config: `deploy/k8s/base/monitoring/README.md`

---

## Related Resources

- PrometheusRules: `deploy/k8s/base/monitoring/prometheusrule-slo.yaml`, `slo-burn-rate-rules.yaml`
- SLO dashboards: `docs/ops/runbooks/SLO_DASHBOARDS_SETUP.md`
- SLA reporting: `docs/policies/operations/SLA_REPORTING.md`
- Incident response: `docs/ops/runbooks/INCIDENT_RESPONSE.md`
- Post-deploy gate control flow: `docs/ops/runbooks/POST_DEPLOY_GATE.md`
- Alert severity matrix: `docs/reference/operations/ALERT_SEVERITY_MATRIX.md`
