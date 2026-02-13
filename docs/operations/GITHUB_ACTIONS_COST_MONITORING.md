# GitHub Actions Cost Monitoring

<!-- Last verified: 2026-02-14 -->

This document provides guidance on monitoring GitHub Actions usage, budget thresholds, alert setup, and workflow optimization recommendations to control CI/CD costs for the Mereka Academy Open edX platform.

## Overview

GitHub Actions provides free minutes for public repositories and includes 2,000 free minutes/month for private repositories on the Free plan. The Mereka Academy repository uses GitHub Actions for CI/CD workflows including linting, image builds, deployments, and scheduled operational audits.

**Key metrics**:
- **Total minutes used**: Cumulative minutes used across all workflows in the billing period
- **Included minutes**: Free minutes included in the GitHub plan (2,000 for Free plan)
- **Paid minutes**: Minutes beyond the included quota (charged per minute, varies by runner OS)

**Pricing** (as of 2026):
- **Linux runners**: $0.008/minute
- **Windows runners**: $0.016/minute
- **macOS runners**: $0.08/minute

## Checking GitHub Actions Usage

### Via GitHub CLI

The `gh` CLI provides programmatic access to billing data via the GitHub API.

```bash
# Check Actions usage for the organization
gh api /orgs/Biji-Biji-Initiative/settings/billing/actions \
  --jq '{
    total_minutes_used: .total_minutes_used,
    included_minutes: .included_minutes,
    total_paid_minutes_used: .total_paid_minutes_used,
    minutes_used_breakdown: .minutes_used_breakdown
  }'

# Example output:
# {
#   "total_minutes_used": 1500,
#   "included_minutes": 2000,
#   "total_paid_minutes_used": 0,
#   "minutes_used_breakdown": {
#     "UBUNTU": 1200,
#     "MACOS": 300,
#     "WINDOWS": 0
#   }
# }
```

**Explanation**:
- `total_minutes_used`: Total minutes consumed this billing cycle
- `included_minutes`: Free minutes allocated to the plan
- `total_paid_minutes_used`: Billable minutes (total - included)
- `minutes_used_breakdown`: Per-OS breakdown (useful for cost attribution)

### Via GitHub Web UI

1. Navigate to **Organization Settings** → **Billing and plans** → **Plans and usage**
2. Click **Usage this month** under **Actions & Packages**
3. View detailed breakdown by repository, workflow, and runner OS

### Via Automated Script

A verification script is provided to check usage programmatically:

```bash
# Check current usage and warn if approaching limit
./scripts/qa/verify-github-actions-cost.sh

# Expected output:
# GitHub Actions Usage Report
# ===========================
# Total minutes used: 1500 / 2000 (75.0%)
# Paid minutes: 0
# Status: OK (within budget)
#
# Breakdown by OS:
#   Ubuntu: 1200 minutes
#   macOS: 300 minutes
#   Windows: 0 minutes
#
# ⚠ Warning: Usage above 80% threshold
```

## Budget Thresholds and Alerts

### Setting Up Spending Limits

GitHub allows setting a spending limit for Actions to prevent unexpected charges.

**Via GitHub Web UI**:
1. Navigate to **Organization Settings** → **Billing and plans** → **Spending limits**
2. Set **Actions spending limit** (e.g., $10/month)
3. Enable **Email notifications when approaching limit**

**Via GitHub CLI** (requires admin token):
```bash
# Set spending limit to $10/month
gh api -X PUT /orgs/Biji-Biji-Initiative/settings/billing/actions \
  --field spending_limit=10

# Enable email notifications
gh api -X PUT /orgs/Biji-Biji-Initiative/settings/billing/actions \
  --field email_billing_contact=true
```

### Alert Thresholds

We use the following thresholds to trigger alerts:

| Threshold | Usage Level | Alert Severity | Action |
|-----------|-------------|----------------|--------|
| 80% | 1,600 / 2,000 minutes | Warning | Review workflow usage, identify optimization opportunities |
| 90% | 1,800 / 2,000 minutes | Critical | Disable non-critical scheduled workflows, defer image builds |
| 100% | 2,000 / 2,000 minutes | Critical | All workflows disabled (except critical deployments), manual approval required |

**Implementation**: The `verify-github-actions-cost.sh` script exits with status codes based on usage:
- Exit 0: Usage < 80% (OK)
- Exit 1: Usage >= 80% (Warning)
- Exit 2: Usage >= 90% (Critical)

### Email Notifications

GitHub sends email notifications to billing contacts when:
- Spending approaches the configured spending limit (at 75%, 90%, 100%)
- Payment fails for paid minutes
- Free minutes quota is exhausted

**Configure billing contacts**:
1. Navigate to **Organization Settings** → **Billing and plans** → **Billing emails**
2. Add billing contact email addresses
3. Enable **Send billing emails** checkbox

## Workflow Optimization Recommendations

### Use Caching

Caching dependencies reduces build time and minutes consumed.

**Example: Cache Node modules in MFE builds**:
```yaml
- name: Cache Node modules
  uses: actions/cache@v3
  with:
    path: |
      ~/.npm
      **/node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

**Example: Cache Docker layers**:
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v2
  with:
    buildkitd-flags: --cache-to type=gha,mode=max --cache-from type=gha
```

### Minimize Matrix Builds

Matrix strategies multiply job execution time. Limit matrix dimensions to necessary variations.

**Before** (wasteful):
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    python-version: [3.8, 3.9, 3.10, 3.11]
# 4 OS × 4 Python = 16 jobs
```

**After** (optimized):
```yaml
strategy:
  matrix:
    os: [ubuntu-latest]
    python-version: [3.10]
# 1 job
```

**Justification**: Open edX deployment only runs on Ubuntu/Linux, so testing macOS/Windows is unnecessary.

### Use `continue-on-error: true` Sparingly

Setting `continue-on-error: true` allows workflows to succeed even when steps fail. This prevents wasted re-runs but hides failures.

**Current usage**:
- **Spec linting**: `continue-on-error: true` (non-blocking during migration)
- **Observability audits**: `continue-on-error: true` (advisory checks)

**Recommendation**: Remove `continue-on-error: true` after Phase 5 migration (see `specs/spec-enforcement_spec.md`).

### Optimize Docker Image Builds

Docker image builds (especially Open edX platform) consume the most minutes.

**Optimizations**:
1. **Build only on changes**: Use `paths` filter to skip builds when unrelated files change
   ```yaml
   on:
     push:
       paths:
         - 'infrastructure/tutor/**'
         - 'deploy/k8s/**'
         - '.github/workflows/image-build.yml'
   ```

2. **Use smaller base images**: Prefer `alpine` or `slim` variants
3. **Multi-stage builds**: Discard build dependencies in final image
4. **Parallel builds**: Build independent images concurrently (not sequentially)

### Limit Scheduled Workflow Frequency

Scheduled workflows consume minutes even when code hasn't changed.

**Current scheduled workflows**:
- **Observability audits**: Daily at 00:00 UTC
- **DR evidence bundle**: Weekly on Mondays
- **Health checks**: Hourly

**Recommendations**:
1. **Reduce frequency**: Change daily audits to weekly
   ```yaml
   # Before
   schedule:
     - cron: '0 0 * * *'  # Daily

   # After
   schedule:
     - cron: '0 0 * * 1'  # Weekly on Mondays
   ```

2. **Use external monitoring**: Move health checks to Prometheus/Grafana (no GitHub Actions minutes)

### Use Self-Hosted Runners (Future)

Self-hosted runners consume zero GitHub Actions minutes. Consider deploying runners on GCP VMs for frequent workflows.

**Pros**:
- Zero cost for runner time
- Faster builds (closer to GCP resources)
- Unlimited concurrency

**Cons**:
- Operational overhead (runner maintenance, security updates)
- GCP VM costs (but cheaper than GitHub Actions paid minutes)

**When to consider**: If monthly usage exceeds included minutes consistently.

## Workflow Cost Attribution

Use the GitHub CLI to identify high-cost workflows.

```bash
# Get workflow runs for the last 7 days
gh api /repos/Biji-Biji-Initiative/mereka-lms/actions/runs \
  --jq '.workflow_runs[] | select(.created_at > "2026-02-07T00:00:00Z") | {
    name: .name,
    created_at: .created_at,
    run_duration_ms: .run_duration_ms,
    billable_minutes: (.run_duration_ms / 60000)
  }' \
  | jq -s 'group_by(.name) | map({
    workflow: .[0].name,
    total_runs: length,
    total_minutes: (map(.billable_minutes) | add)
  }) | sort_by(.total_minutes) | reverse'

# Example output:
# [
#   {
#     "workflow": "Image Build (openedx)",
#     "total_runs": 5,
#     "total_minutes": 450
#   },
#   {
#     "workflow": "CI",
#     "total_runs": 20,
#     "total_minutes": 120
#   }
# ]
```

**High-cost workflows** (prioritize for optimization):
1. **Image Build (openedx)**: 30-45 minutes per build
2. **Image Build (mfe)**: 15-20 minutes per build
3. **iOS Build**: 10-15 minutes per build (macOS runner, 10x cost)

## Monitoring Dashboard (Future)

A Grafana dashboard can visualize GitHub Actions usage trends.

**Data source**: GitHub Actions API via Prometheus exporter or custom script

**Panels**:
- **Total minutes used** (time-series)
- **Percentage of included minutes** (gauge)
- **Cost per workflow** (bar chart)
- **Runner OS breakdown** (pie chart)

**Implementation**: Use `scripts/qa/verify-github-actions-cost.sh` as a data collection script, export metrics to Prometheus pushgateway.

## Related Documentation

- **CI/CD Pipeline Spec**: `specs/ci-cd-pipeline_spec.md` - Workflow definitions and gates
- **CI/CD Setup**: `docs/operations/CI_CD_SETUP.md` - GitHub Actions configuration
- **Release Checklist**: `docs/operations/RELEASE_CHECKLIST.md` - Deployment workflows

## Verification Script

Location: `scripts/qa/verify-github-actions-cost.sh`

**Usage**:
```bash
# Check current usage
./scripts/qa/verify-github-actions-cost.sh

# Use in CI (exit non-zero if over budget)
./scripts/qa/verify-github-actions-cost.sh || echo "⚠ GitHub Actions usage high"
```

**Exit codes**:
- `0`: Usage < 80% (OK)
- `1`: Usage >= 80% (Warning)
- `2`: Usage >= 90% (Critical)

## Cost Reduction Checklist

- [ ] Enable dependency caching for all workflows
- [ ] Use `paths` filter to skip unnecessary builds
- [ ] Review scheduled workflows, reduce frequency
- [ ] Limit matrix builds to essential variations
- [ ] Remove `continue-on-error: true` from non-critical steps
- [ ] Consolidate related jobs into single workflow
- [ ] Use Docker layer caching for image builds
- [ ] Set spending limit in GitHub billing settings
- [ ] Add billing email notifications
- [ ] Run `verify-github-actions-cost.sh` weekly
- [ ] Evaluate self-hosted runners if usage consistently exceeds quota
