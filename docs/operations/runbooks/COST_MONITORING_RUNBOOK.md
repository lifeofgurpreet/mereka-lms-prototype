# GitHub Actions Cost Monitoring Runbook

> **Spec**: `specs/github-actions-cost-monitoring_spec.md`
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-19

This runbook covers operational procedures for GitHub Actions cost monitoring, budget enforcement, and optimization.

## Status

**Implementation Status**: NOT YET IMPLEMENTED

The GitHub Actions cost monitoring pipeline (Prometheus exporter, Grafana dashboard, alerting, daily reports) is not yet deployed. This runbook documents the intended operational procedures for when it is implemented.

## Cost Tracking

### Viewing Current Spend

Once implemented, cost data will be available via:

```bash
# Query Prometheus for monthly budget consumed
curl -s "http://prometheus:9090/api/v1/query?query=github_actions_monthly_budget_consumed_percent"

# View daily cost report (generated at 00:00 UTC)
kubectl logs -n mereka-lms -l app=github-actions-cost-reporter --tail=100
```

### Cost Calculation Verification

To validate calculated cost matches GitHub billing (within ±5%):

1. Access GitHub billing at: Settings → Billing → Actions
2. Compare against Prometheus metric `github_actions_workflow_cost_usd`
3. Acceptable variance: ±5% per AC-GAC-012

## Alerting

### Threshold Alerts (80% / 100% / 150% of budget)

Alerts fire via PrometheusRule `github-actions-cost-alerts` (once deployed). Check with:

```bash
kubectl get prometheusrule -n mereka-lms | grep github-actions
```

Alert delivery SLA: within 5 minutes of threshold breach (AC-GAC-013).

### Anomaly Alerts

Triggered on:
- >50% day-over-day cost spike
- New workflow consuming >5% of monthly budget
- Workflow duration >2x historical average

## Cost Controls

### Budget Configuration

Budget defined in `.github/actions-budget.yml` (once created):

```yaml
monthly_limit_usd: <budget>
hard_limit_usd: <hard_limit>
alert_thresholds: [0.80, 1.00, 1.50]
workflow_duration_limits:
  pr_checks: 300      # 5 minutes
  full_verify: 1800   # 30 minutes
  builds: 2700        # 45 minutes
```

### Emergency Workflow Pause (95% budget)

When 95% of budget is consumed, non-critical workflows are automatically paused (AC-GAC-006). To manually pause:

```bash
# Disable non-critical workflow (GitHub CLI)
gh workflow disable "Non-Critical Workflow Name"

# Re-enable after budget resets
gh workflow enable "Non-Critical Workflow Name"
```

## Cost Optimization

### Optimization Recommendations

Weekly analysis identifies high-cost workflows (AC-GAC-005). Review recommendations:

```bash
# View weekly analysis report
kubectl logs -n mereka-lms -l app=github-actions-weekly-analyzer --tail=200
```

Optimization settings applied (AC-GAC-011):
- Cache strategy: restore `node_modules`, Docker layers
- Concurrency limits: cancel in-progress runs on new push
- Conditional execution: skip non-impacted jobs on path filters
- Self-hosted runner options: for long-running builds

## Observability

### Grafana Dashboard

Dashboard URL: `/dashboards/github-actions-cost` (once deployed)

Panels include (AC-GAC-008):
- Current spend vs monthly budget
- Daily spend trend (last 30 days)
- Top 5 expensive workflows
- Projected month-end cost
- Month-over-month comparison

### Prometheus Metrics (AC-GAC-007)

| Metric | Description |
|--------|-------------|
| `github_actions_workflow_duration_seconds` | Duration per workflow run |
| `github_actions_workflow_cost_usd` | Cost in USD per workflow run |
| `github_actions_monthly_budget_consumed_percent` | % of monthly budget consumed |

## References

- `specs/github-actions-cost-monitoring_spec.md`
- GitHub Actions billing: https://docs.github.com/en/billing/managing-billing-for-github-actions
