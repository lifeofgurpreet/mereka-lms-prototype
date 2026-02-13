---
title: GitHub Actions Cost Monitoring
type: "feature_spec"
status: approved
owner: Platform Team
last_updated: 2026-02-12
version: "1.0.0"
priority: high
tier: 2
depends_on:
  - ci-cd-pipeline_spec.md
references:
  - specs/cross-cutting-requirements_spec.md
  - docs/operations/runbooks/CI_CD_RUNBOOK.md
  - .github/workflows/verify-specs.yml
---

# GitHub Actions Cost Monitoring

# Human Summary

## What we're building
An automated cost monitoring and alerting system for GitHub Actions CI/CD workflows. It tracks workflow minutes consumed, calculates costs by runner type, generates daily reports, and enforces budget limits to prevent surprise billing.

## Why it matters
GitHub Actions costs can balloon unexpectedly with matrix builds, long-running verification scripts, and frequent PR cycles. Without monitoring, a 126-script verification suite running 10 PRs/day could cost $580/month. This system keeps costs under the $50/month target with proactive alerts and automatic workflow throttling.

## Success looks like
- GitHub Actions costs stay below $50/month consistently
- Budget alerts fire within 5 minutes of threshold breaches
- Cost dashboard shows real-time spend vs budget with projections
- Non-critical workflows auto-pause when budget reaches 95%

# Agent Contract

## Scope
Cost tracking, budget alerting, workflow duration limits, optimization recommendations, and monthly cost caps for GitHub Actions.

## Non-goals
- GitHub Actions workflow authoring (covered in ci-cd-pipeline_spec.md)
- Self-hosted runner infrastructure
- Cost optimization for non-GitHub CI systems

## Context

GitHub Actions provides generous free minutes (2,000/month for free accounts, 3,000/month for Pro), but costs can balloon unexpectedly with:
- Matrix builds (multiply runs by matrix dimension)
- Long-running verification scripts
- Frequent PR cycles
- Background workflows

**Problem**: Without monitoring, we could exceed free tier and incur unexpected costs ($0.008/minute for Linux runners after free tier).

**Example Risk Scenario**:
- 126 verification scripts
- 2-minute timeout each
- 10 PRs/day
- = 126 × 2 × 10 × 30 = **75,600 minutes/month**
- Cost: (75,600 - 3,000) × $0.008 = **$580.80/month**

**Goal**: Keep GitHub Actions costs **<$50/month** through monitoring, optimization, and alerting.

---

## Requirements

### Functional Requirements

#### AC-001: Workflow Cost Tracking
**Given** GitHub Actions workflows execute
**When** workflow runs complete
**Then** total minutes consumed must be tracked per workflow
**And** cost calculated based on runner type (Linux $0.008/min, macOS $0.08/min, Windows $0.016/min)

#### AC-002: Daily Cost Report
**Given** workflows run throughout the day
**When** end of day (00:00 UTC)
**Then** automated report must be generated showing:
- Total minutes consumed (by workflow)
- Estimated cost for the day
- Month-to-date total
- Projected month-end cost
- Comparison to budget ($50 target, $100 hard limit)

#### AC-003: Budget Alerts
**Given** workflow costs are being tracked
**When** cost thresholds are exceeded
**Then** alerts must be sent:
- **Warning** (80% of budget = $40/month): Slack notification
- **Critical** (100% of budget = $50/month): Slack + email notification
- **Emergency** (150% of budget = $75/month): Escalate to platform lead

#### AC-004: Workflow Duration Limits
**Given** workflows are configured
**When** workflow job executes
**Then** maximum duration must be enforced:
- Fast verification (PR checks): **5 minutes** max
- Full verification (merge to main): **30 minutes** max
- Build workflows: **45 minutes** max
**And** jobs exceeding limits must fail with cost warning

#### AC-005: Cost Optimization Recommendations
**Given** workflow execution history
**When** weekly cost analysis runs
**Then** automated recommendations must be generated:
- Identify high-cost workflows (>10% of total minutes)
- Suggest optimizations (caching, parallelization, timeout reduction)
- Flag inefficient patterns (excessive re-runs, redundant checks)

#### AC-006: Monthly Cost Cap
**Given** monthly cost approaches hard limit
**When** 95% of budget consumed ($95 if $100 limit)
**Then** non-critical workflows must be paused:
- Verification workflows continue (required for merges)
- Documentation builds paused
- Scheduled jobs paused
**And** platform team notified for budget increase decision

---

### Monitoring Requirements

#### AC-007: Workflow Execution Metrics
**Given** Prometheus metrics are configured
**When** workflows execute
**Then** metrics must be exported:
```
github_actions_workflow_duration_seconds{workflow="verify-specs",conclusion="success"}
github_actions_workflow_cost_usd{workflow="verify-specs",runner="ubuntu-latest"}
github_actions_monthly_budget_consumed_percent{month="2026-02"}
```

#### AC-008: Cost Dashboard
**Given** Grafana is configured
**When** operators view analytics
**Then** cost dashboard must display:
- Current month spend vs budget (gauge)
- Daily spend trend (time series)
- Top 5 expensive workflows (bar chart)
- Projected month-end cost (forecast)
- Historical cost comparison (month-over-month)

#### AC-009: Anomaly Detection
**Given** workflow execution history
**When** cost patterns deviate from normal
**Then** anomalies must be detected:
- Sudden spike (>50% increase day-over-day)
- New workflow consuming >5% of budget
- Workflow duration increased >2x
**And** alerts sent to platform team

---

### Configuration Requirements

#### AC-010: Budget Configuration
**Given** repository configuration
**When** budget is defined
**Then** budget must be configurable via:
- `.github/actions-budget.yml` file
- Environment variables (for overrides)
**And** default budget is $50/month

**Example Configuration**:
```yaml
# .github/actions-budget.yml
budget:
  monthly_limit_usd: 50
  hard_limit_usd: 100
  alerts:
    - threshold_percent: 80
      channel: slack
      recipients: ["#platform-alerts"]
    - threshold_percent: 100
      channel: slack,email
      recipients: ["#platform-alerts", "platform-team@mereka.io"]

  workflow_limits:
    "verify-specs.yml":
      max_duration_minutes: 30
      priority: high
    "build-openedx.yml":
      max_duration_minutes: 45
      priority: high
    "docs-deploy.yml":
      max_duration_minutes: 10
      priority: low
```

#### AC-011: Cost Optimization Settings
**Given** workflows are configured
**When** cost optimization is enabled
**Then** settings must be applied:
- Cache strategy (Docker layers, npm/pip dependencies, build artifacts)
- Concurrency limits (max parallel jobs)
- Conditional execution (skip if no relevant changes)
- Self-hosted runner option (for high-volume workflows)

---

### Verification Requirements

#### AC-012: Cost Tracking Accuracy
**Given** workflows execute
**When** costs are calculated
**Then** calculated cost must match GitHub's billing within ±5%
**And** discrepancies >5% must be investigated

**Verification**:
```bash
#!/bin/bash
# @spec: github-actions-cost-monitoring_spec.md
# @covers: AC-012

# Fetch GitHub Actions usage from API
gh api /repos/Biji-Biji-Initiative/mereka-lms/actions/cache/usage

# Calculate expected cost
# Compare with tracked cost
# Assert difference <5%
```

#### AC-013: Alert Delivery
**Given** cost threshold is exceeded
**When** alert is triggered
**Then** notification must be delivered within **5 minutes**
**And** notification must include:
- Current spend and budget
- Triggering workflow and cost
- Recommended actions
- Link to cost dashboard

**Verification**:
```bash
#!/bin/bash
# @spec: github-actions-cost-monitoring_spec.md
# @covers: AC-013

# Simulate threshold breach
# Verify Slack message received within 5 min
# Verify email received (if configured)
# Validate message content
```

#### AC-014: Dashboard Availability
**Given** cost monitoring is deployed
**When** operators access Grafana
**Then** cost dashboard must be available at `/dashboards/github-actions-cost`
**And** all panels must render without errors

**Verification**:
```bash
#!/bin/bash
# @spec: github-actions-cost-monitoring_spec.md
# @covers: AC-014

kubectl port-forward -n mereka-lms svc/grafana 3000:3000
curl -I http://localhost:3000/dashboards/github-actions-cost
# Assert 200 OK
```

---

### Non-Functional Requirements

See `specs/cross-cutting-requirements_spec.md` for:
- Security (secret scanning for GitHub tokens)
- Observability (Prometheus metrics, Grafana dashboards)
- Documentation (runbook for cost optimization)

**Performance**:
- Cost calculation latency: <1 second per workflow
- Metrics export delay: <30 seconds after workflow completion
- Dashboard load time: <2 seconds

**Reliability**:
- Cost tracking uptime: 99.9%
- Alert delivery: 99% within 5 minutes
- Data retention: 6 months of cost history

---

## Implementation Notes

### GitHub Actions API
Use GitHub REST API for usage data:
```bash
# Get workflow runs
gh api /repos/{owner}/{repo}/actions/runs

# Get usage summary
gh api /repos/{owner}/{repo}/actions/cache/usage
```

### Cost Calculation
```python
# Cost per minute (as of 2026-02)
RUNNER_COSTS = {
    "ubuntu-latest": 0.008,  # Linux
    "macos-latest": 0.08,    # macOS (10x more expensive!)
    "windows-latest": 0.016,  # Windows (2x Linux)
}

def calculate_cost(workflow_run):
    runner_type = workflow_run["runner_os"].lower()
    duration_minutes = workflow_run["duration_seconds"] / 60
    cost_per_minute = RUNNER_COSTS.get(runner_type, 0.008)
    return duration_minutes * cost_per_minute
```

### Free Tier Tracking
```python
FREE_MINUTES = {
    "free": 2000,
    "pro": 3000,
    "team": 3000,
    "enterprise": 50000,
}

def get_billable_minutes(total_minutes, account_type="pro"):
    free_minutes = FREE_MINUTES[account_type]
    return max(0, total_minutes - free_minutes)
```

### Optimization Strategies

**1. Cache Aggressively**:
```yaml
- uses: actions/cache@v3
  with:
    path: |
      ~/.cache/pip
      ~/.npm
      /var/lib/docker
    key: ${{ runner.os }}-deps-${{ hashFiles('**/requirements.txt', '**/package-lock.json') }}
```

**2. Conditional Execution**:
```yaml
jobs:
  verify-docs:
    if: contains(github.event.head_commit.message, '[docs]') || github.event_name == 'schedule'
```

**3. Matrix Optimization**:
```yaml
# Before: 13 parallel jobs × 30 min = 390 minutes
# After: Sequential groups of 3 = ~130 minutes
strategy:
  matrix:
    group: [1, 2, 3, 4]
  max-parallel: 3
```

**4. Timeout Enforcement**:
```yaml
jobs:
  verify:
    timeout-minutes: 30  # Hard limit
```

---

## Test Plan

### Unit Tests
1. Cost calculation accuracy
2. Budget threshold detection
3. Alert message formatting

### Integration Tests
1. GitHub API integration
2. Prometheus metrics export
3. Slack notification delivery
4. Grafana dashboard rendering

### End-to-End Tests
1. Full month simulation (workflow runs → cost tracking → budget alerts)
2. Budget cap enforcement (pause workflows when limit reached)
3. Cost optimization recommendations

---

## Deployment

### Prerequisites
- GitHub Personal Access Token with `repo` and `workflow` scopes
- Prometheus + Grafana deployed
- Slack webhook URL for notifications

### Deployment Steps

1. **Configure Budget**:
```bash
cp .github/actions-budget.example.yml .github/actions-budget.yml
# Edit budget limits and alert thresholds
git add .github/actions-budget.yml
git commit -m "feat: configure GitHub Actions budget"
```

2. **Deploy Cost Tracker**:
```bash
# Create K8s CronJob for cost tracking
kubectl apply -f deploy/k8s/base/monitoring/github-actions-cost-tracker.yaml

# Verify CronJob scheduled
kubectl get cronjob -n mereka-lms github-actions-cost-tracker
```

3. **Import Grafana Dashboard**:
```bash
kubectl create configmap -n mereka-lms grafana-dashboard-gh-actions \
  --from-file=deploy/k8s/base/monitoring/dashboards/github-actions-cost.json

kubectl label configmap -n mereka-lms grafana-dashboard-gh-actions \
  grafana_dashboard=1
```

4. **Verify Metrics**:
```bash
# Check Prometheus targets
kubectl port-forward -n mereka-lms svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Query metrics
curl -s http://localhost:9090/api/v1/query?query=github_actions_monthly_budget_consumed_percent | jq
```

---

## Rollback

If cost monitoring causes issues:

```bash
# Pause cost tracker CronJob
kubectl patch cronjob -n mereka-lms github-actions-cost-tracker -p '{"spec":{"suspend":true}}'

# Remove budget enforcement from workflows
# (workflows continue running, just without cost caps)
```

---

## Related Documentation

- `.github/workflows/verify-specs.yml` - Main verification workflow
- `docs/operations/runbooks/CI_CD_RUNBOOK.md` - CI/CD operations
- `specs/ci-cd-pipeline_spec.md` - CI/CD requirements
- [GitHub Actions Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)

---

**Sources**:
- [GitHub Actions Pricing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [GitHub Actions Usage API](https://docs.github.com/en/rest/actions/workflow-runs)
- [Prometheus Client Libraries](https://prometheus.io/docs/instrumenting/clientlibs/)

---

**Last Updated**: 2026-02-12
**Status**: Approved - ready for implementation
