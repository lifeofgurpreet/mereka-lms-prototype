---
spec: slo-sla-service-level-management_spec.md
tier: 2
status: draft
last_updated: '2026-02-10'
plan: slo-sla-service-level-management_plan.md
---

# Test Plan: SLO/SLA Definitions & Service Level Management

**Source Spec**: `specs/slo-sla-service-level-management_spec.md`

## Test Framework

This project uses **shell verification scripts** (`scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh`) as the primary test infrastructure for infrastructure-as-code. Application-level tests are not applicable -- this spec defines monitoring rules, dashboards, and operational processes, not application code.

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts with `set -euo pipefail` | `scripts/qa/verify-*.sh` |
| `kubectl_check` | `kubectl` commands | Inline in verification scripts |
| `manual_verification` | Human checklist | Documented belowwith owner + justification |
| `ci_workflow` | GitHub Actions | `.github/workflows/` |

## Test Matrix

### Service Tier Classification (AC-001, AC-002)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-001 | Every deployment in `mereka-lms` namespace maps toexactly one service tier | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | kubectl access to GKE cluster;`docs/operations/SERVICE_TIERS.md` exists |
| AC-001 (negative) | Script fails if an unknown deployment exists that is not classified in any tier | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | Deploy a test deployment, verify script reports unclassified service |
| AC-002 | For every tier, SLO availability target > SLA availability target | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | Tier definitions from spec hardcoded in script |
| AC-002 (negative) | Script fails if any tier has SLO <= SLA| `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | Inject invalid tier definition |

### SLI Measurement (AC-003, AC-004, AC-005, AC-006)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-003 | LMS `/metrics` endpoint returns `http_request_duration_seconds` histogram buckets | `kubectl_check` | `kubectlexec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics \| grep http_request_duration_seconds` | django-prometheusinstalled and configured |
| AC-003 (negative) | Script reports failure if `/metrics` returns 400 or does not contain histogram data | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | django-prometheus NOT installed (current state) |
| AC-004 | Prometheus returns a value between 0 and 1 for `mereka:http_requests:availability_ratio_5m{service="lms"}` | `kubectl_check` | `kubectl exec -n monitoring deploy/prometheus-kube-prometheus-prometheus -- promtool query instant 'mereka:http_requests:availability_ratio_5m{service="lms"}'` | Recording rules deployed; LMS receiving traffic |
| AC-004 (negative) | Script reports failure if recording rule returns no data or value outside [0,1] | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | Recording rulesnot yet deployed |
| AC-005 | All recording rules defined in spec exist in PrometheusRule CRD | `kubectl_check` | `kubectl get prometheusrule-n mereka-lms -o yaml \| grep "record: mereka:"` | PrometheusRule `slo-recording-rules` deployed |
| AC-005 (negative) | Script reports failure if any expectedrecording rule name is missing | `shell_verification` | `scripts/qa/verify-sli-foundation.sh` | Incomplete PrometheusRuledeployment |
| AC-006 | GCP uptime checks exist for all Tier 1 and Tier 2service public endpoints | `shell_verification` | `gcloud monitoring uptime list-configs --project=mereka-lms --format=json` | gcloud CLI authenticated with project access |
| AC-006 (negative) | Script reports failure if any Tier 1/2public endpoint lacks an uptime check | `shell_verification`| `scripts/qa/verify-sli-foundation.sh` | Delete a test uptime check, verify script detects gap |

### Error Budget (AC-007, AC-008, AC-009)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-007 | `mereka:slo:error_budget_remaining_ratio` returnsvalues between 0 and 1 for each service | `kubectl_check` | `scripts/qa/verify-error-budget.sh` | 30 days of metrics data;recording rules deployed |
| AC-007 (negative) | Script reports warning if less than 30days of data available (new deployment) | `shell_verification` | `scripts/qa/verify-error-budget.sh` | Fresh Prometheus with <30d retention |
| AC-008 | Grafana SLO Overview dashboard loads at `grafana.mereka.io/d/mereka-slo-overview` with all required panels | `shell_verification` | `scripts/qa/verify-error-budget.sh` (curl Grafana API) | Grafana accessible; dashboard provisioned |
| AC-008 (negative) | Script reports failure if dashboard does not exist or is missing required panels | `shell_verification` | `scripts/qa/verify-error-budget.sh` | Dashboard not yetprovisioned |
| AC-009 | When error budget drops below 50%, Slack notification is received within 5 minutes | `manual_verification` | Simulate by scaling LMS to 0 replicas for 5 minutes | Alertmanager routing configured; Slack webhook active |

### Deployment Gating (AC-010, AC-011, AC-012)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-010 | Gate check passes without approval when error budget >= 50% for all Tier 1 services | `shell_verification` | `scripts/qa/verify-deployment-gate.sh` | Gate check script exists; mock Prometheus response with budget=0.75 |
| AC-010 (negative) | Gate check does NOT pass when `ENABLE_DEPLOYMENT_GATING=true` and budget < 50% | `shell_verification` | `scripts/qa/verify-deployment-gate.sh` | Mock Prometheusresponse with budget=0.30 |
| AC-011 | Gate check blocks deployment when error budget < 25% for any Tier 1 service | `shell_verification` | `scripts/qa/verify-deployment-gate.sh` | Mock Prometheus response withbudget=0.15 |
| AC-011 (negative) | Gate check allows deployment with `--override` flag even when budget < 25% | `shell_verification` |`scripts/qa/verify-deployment-gate.sh` | Mock Prometheus response with budget=0.15; override flag provided |
| AC-012 | Override log entry contains: approver, timestamp,justification, deployment identifier | `shell_verification` |`scripts/qa/verify-deployment-gate.sh` | Run gate check with`--override`; parse log output |
| AC-012 (negative) | Override without required justificationargument fails with error message | `shell_verification` | `scripts/qa/verify-deployment-gate.sh` | Run gate check with `--override` but no `--reason` |

### Performance Regression Detection (AC-013, AC-014, AC-015)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-013 | `LatencyRegressionSpike` alert rule exists in PrometheusRule with correct threshold (2x baseline, 15m duration)| `kubectl_check` | `scripts/qa/verify-regression-detection.sh` | PrometheusRule deployed with regression rules |
| AC-013 (negative) | Alert fires when simulated latency exceeds 2x baseline for 15 minutes | `manual_verification` | Introduce artificial latency via network policy or test endpoint;verify alert in Alertmanager | GKE cluster access; network policy capability |
| AC-014 | Regression alert annotation includes deployment identifier and commit SHA when regression within 30 minutes ofdeploy | `kubectl_check` | `scripts/qa/verify-regression-detection.sh` (check alert rule annotations template) | Annotation script integrated; recent deployment exists |
| AC-014 (negative) | Regression alert does NOT include deployment info when no deploy in last 30 minutes | `manual_verification` | Trigger regression without recent deploy; verify annotation is absent | Alert rule deployed |
| AC-015 | Grafana SLO dashboards show vertical deployment markers on latency and availability panels | `shell_verification` | `scripts/qa/verify-regression-detection.sh` (check Grafana API for annotations) | Grafana accessible; at least one deployment annotation posted |
| AC-015 (negative) | Dashboard renders correctly even with zero deployment annotations | `manual_verification` | Load dashboard with no annotations; verify no errors | Dashboard provisioned |

### Maintenance Windows (AC-016, AC-017)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-016 | Maintenance window duration excluded from SLA availability calculation | `manual_verification` | Declare test maintenance window, generate SLA report, verify window excluded from availability numerator and denominator | Maintenance script + report script operational |
| AC-016 (negative) | Maintenance window overrun (beyond declared end) counts against SLA | `manual_verification` | Declare 1-hour window, simulate 2-hour overrun, verify overage counted in SLA report | Maintenance script + report script |
| AC-017 | Monthly SLA report contains maintenance window with start time, end time, and scope | `shell_verification` | `scripts/qa/verify-sla-report-security.sh` (extended to check maintenance section) | At least one maintenance window declared; report generated |

### Incident Communication (AC-018, AC-019)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-018 | P1 incident acknowledged within 15 minutes of alert firing | `manual_verification` | Simulate P1 alert; measuretime to acknowledgement by on-call engineer | On-call schedule active; Alertmanager routing configured |
| AC-019 | Postmortem published within 5 business days of P1/P2 resolution with required sections | `manual_verification`| After a P1/P2 incident, verify postmortem document contains: timeline, root cause, impact, remediation, prevention | Postmortem template created |

### On-Call (AC-020, AC-021)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-020 | Every week has primary and secondary on-call assigned; no engineer >7 consecutive days | `manual_verification`| Inspect on-call schedule document/tool for current and nextweeks | On-call schedule documented |
| AC-020 (negative) | Verification catches if schedule has >7consecutive days for any engineer | `shell_verification` | `scripts/qa/verify-oncall-schedule.sh` (if on-call is trackedin a parseable format) | On-call schedule in parseable format|
| AC-021 | P1 alert auto-escalates to secondary when primarydoes not acknowledge within 15 minutes | `manual_verification` | Simulate P1 alert with primary unreachable; verify Alertmanager escalates to secondary | Alertmanager escalation config; two on-call contacts |

### Reporting (AC-022, AC-023)

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-022 | Monthly SLA report contains: per-service availability, latency percentiles, error budget status, incident summary, maintenance log | `shell_verification` | `scripts/qa/generate-sla-report.sh` + manual section review | At least 1 month of production metrics; all previous phases complete |
| AC-022 (negative) | Report generation fails gracefully withclear error if Prometheus has <30 days of data | `shell_verification` | Run `generate-sla-report.sh` against fresh Prometheus; verify non-zero exit + error message | Fresh Prometheusdeployment |
| AC-023 | Generated SLA report contains no internal IP addresses, secret names, or infrastructure hostnames | `shell_verification` | `scripts/qa/verify-sla-report-security.sh` | Generated report file |
| AC-023 (negative) | Security check catches internal detailsif sanitization is broken | `shell_verification` | `scripts/qa/verify-sla-report-security.sh` with intentionally unsanitized report | Test report with embedded internal IPs |

### Edge Cases

| EC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| EC-1 (SLI Data Gap) | Recording rules use `rate()`/`increase()` that handle counter resets; no division-by-zero on gap |`kubectl_check` | Inspect recording rule expressions in `prometheusrule-slo.yaml` | PrometheusRule YAML available |
| EC-2 (Budget Exhaustion) | Incident remediation deploymentsallowed even when error budget is 0% (override mechanism) |`shell_verification` | `scripts/qa/verify-deployment-gate.sh`with budget=0 + override | Gate check script |
| EC-3 (Maintenance Overrun) | Alert fires when maintenance window reaches 75% of declared duration | `manual_verification` | Declare 4-hour window; verify alert at 3-hour mark | MaintenanceWindowOverrun alert deployed |
| EC-4 (Conflicting Signals) | Alert fires when internal Prometheus healthy but external GCP uptime check fails (or vice versa) | `manual_verification` | Block external probe while service is internally healthy; verify signal divergence alert |GCP uptime checks + Prometheus both active |
| EC-5 (Background Job Skew) | Latency SLI excludes bulk APIpaths from user-facing latency calculation | `kubectl_check`| Verify recording rule expressions filter out `/api/bulk_enroll/`, `/api/grades/export/` paths | Recording rule expressions |
| EC-6 (Rate Limit 429) | HTTP 429 responses do not count against availability SLI | `kubectl_check` | Verify recording rule availability expression excludes `status="429"` | Recording rule expressions |
| EC-7 (Partial Degradation) | Composite SLI (availability AND latency) captures "technically up but unusable" state | `kubectl_check` | Verify composite SLI recording rule exists andcombines availability + latency threshold | Recording rule expressions |
| EC-8 (SLO Target Adjustment) | SLO targets are documented as reviewable quarterly; report includes recommendation section | `manual_verification` | Verify quarterly report templateincludes SLO adjustment recommendations section | Quarterly report script |

### NFR Tests

| NFR | Test Case | Type | File / Command | Fixtures / Prerequisites |
|-----|-----------|------|----------------|--------------------------|
| NFR-Perf-1 | SLI metric collection adds <5ms to LMS p99 latency | `manual_verification` | Compare p99 latency before/after django-prometheus rollout | Baseline latency measurement before installation |
| NFR-Perf-2 | SLO dashboard loads within 5 seconds in Grafana | `shell_verification` | `scripts/qa/verify-error-budget.sh` (time curl to Grafana dashboard API) | Grafana accessible |
| NFR-Rel-1 | SLI measurement system alerts when scrape failsfor >10 minutes | `kubectl_check` | Verify `SLIMeasurementDown` alert rule exists | PrometheusRule deployed |
| NFR-Sec-1 | SLA report contains no internal infrastructuredetails | `shell_verification` | `scripts/qa/verify-sla-report-security.sh` | Generated report |

## Test Coverage Summary

| AC Range | Count | shell_verification | kubectl_check | manual_verification | ci_workflow |
|----------|-------|--------------------|---------------|---------------------|-------------|
| AC-001 to AC-006 | 6 | 5 | 3 | 0 | 0 |
| AC-007 to AC-009 | 3 | 2 | 1 | 1 | 0 |
| AC-010 to AC-012 | 3 | 3 | 0 | 0 | 0 |
| AC-013 to AC-015 | 3 | 2 | 1 | 2 | 0 |
| AC-016 to AC-017 | 2 | 1 | 0 | 2 | 0 |
| AC-018 to AC-019 | 2 | 0 | 0 | 2 | 0 |
| AC-020 to AC-021 | 2 | 1 | 0 | 2 | 0 |
| AC-022 to AC-023 | 2 | 2 | 0 | 0 | 0 |
| Edge Cases | 8 | 1 | 4 | 3 | 0 |
| NFRs | 4 | 2 | 1 | 1 | 0 |
| **Total** | **35** | **19** | **10** | **13** | **0** |

**Notes**:
- AC-018, AC-019, AC-020, and AC-021 require `manual_verification` because they test human response times and process adherence that cannot be fully automated.
- `kubectl_check` tests are embedded within `shell_verification` scripts but listed separately where the primary verification is a single kubectl command.
- Edge case EC-3 and EC-4 require infrastructure-level simulation that is not safe to automate in production.
