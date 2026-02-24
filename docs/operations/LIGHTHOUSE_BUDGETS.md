# Lighthouse CI + Bundle Budgets

Tracks Core Web Vitals targets, per-MFE bundle size budgets, and how to
integrate Lighthouse CI into the release evidence pipeline.

---

## Core Web Vitals Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **LCP** (Largest Contentful Paint) | < 2.5 s | Measures load speed of main content |
| **INP** (Interaction to Next Paint) | < 200 ms | Replaced FID as of March 2024 (CWV v4) |
| **CLS** (Cumulative Layout Shift) | < 0.1 | Measures visual stability |

> **INP replaces FID**: Google retired First Input Delay from Core Web Vitals in March 2024.
> All scripts and budgets in this repo reference INP only. FID references are a bug.

---

## MFE Pages in Scope

| MFE | Path | Description |
|-----|------|-------------|
| `authn` | `/authn/login` | Login / registration |
| `learning` | `/learning/course/:id` | Course player |
| `profile` | `/profile` | Learner profile |
| `account` | `/account` | Account settings |
| `discussions` | `/discussions` | Course discussion forums |
| `dashboard` | `/dashboard` | Learner dashboard (served by LMS) |

---

## Bundle Size Budgets

Budgets are enforced via `infrastructure/monitoring/lighthouse-budgets.json`.
The file follows the [Lighthouse budget.json format](https://web.dev/use-lighthouse-for-performance-budgets/).

### Per-MFE JS Thresholds (compressed / gzip)

| MFE | JS Budget | CSS Budget | Image Budget |
|-----|-----------|------------|--------------|
| `authn` | 300 KB | 60 KB | 200 KB |
| `learning` | 500 KB | 80 KB | 500 KB |
| `profile` | 250 KB | 50 KB | 150 KB |
| `account` | 250 KB | 50 KB | 150 KB |
| `discussions` | 350 KB | 60 KB | 200 KB |
| `dashboard` | 400 KB | 70 KB | 300 KB |

### Absolute Ceiling (any page)

- Total JS: **2 MB** (hard limit enforced by `verify-lighthouse-budgets.sh`)
- Total CSS: **500 KB** (hard limit enforced by `verify-lighthouse-budgets.sh`)

---

## Lighthouse CI Setup

### Prerequisites

```bash
npm install -g @lhci/cli
```

### Run Against a Deployed MFE (manual)

```bash
# Example: authn MFE on prod
lhci collect \
  --url="https://apps.academyv2.mereka.io/authn/login" \
  --numberOfRuns=3

lhci assert \
  --budgetsFile=infrastructure/monitoring/lighthouse-budgets.json
```

### Run Against Local Dev

```bash
# Bring up local stack first
tutor local start

lhci collect \
  --url="http://apps.localhost/authn/login" \
  --numberOfRuns=3 \
  --settings.chromeFlags="--ignore-certificate-errors"

lhci assert \
  --budgetsFile=infrastructure/monitoring/lighthouse-budgets.json
```

### GitHub Actions

The workflow `.github/workflows/lighthouse-ci.yml` runs on `workflow_dispatch`
(manual trigger). It is informational (`continue-on-error: true`) until budgets
are established and baselines are captured.

To promote it to a blocking gate, remove `continue-on-error` and add the job
name to the required status checks in branch protection.

---

## Ratcheting (Budget Decrease Only)

Budgets are a ratchet — they should only ever decrease (tighten), never increase
(loosen). The process:

1. Run Lighthouse CI against a new build.
2. If bundle size decreases, **update the budget** to match or slightly above the
   new value (leave a 10% headroom).
3. Open a PR updating `infrastructure/monitoring/lighthouse-budgets.json` with
   the tighter value and the measured evidence.
4. **Never increase a budget** without a documented architectural justification
   reviewed in the PR.

Example ratchet PR title:
```
chore(perf): tighten authn JS budget from 300KB → 240KB (measured 218KB)
```

---

## Integration with Release Evidence Bundle

When running `scripts/infra/assemble-release-evidence.sh`, Lighthouse budget
results should be captured to `var/ci/lighthouse-*.json` and included in the
evidence artifact.

Add to the release evidence step:

```bash
# After lhci collect + assert
cp .lighthouseci/lhr-*.json var/ci/

# Verify budgets are still valid at release time
./scripts/qa/verify-lighthouse-budgets.sh
```

---

## References

- [Lighthouse Budget Docs](https://web.dev/use-lighthouse-for-performance-budgets/)
- [Core Web Vitals (CWV v4)](https://web.dev/vitals/) — INP replaces FID, March 2024
- [INP Explainer](https://web.dev/inp/)
- Budget file: `infrastructure/monitoring/lighthouse-budgets.json`
- Verify script: `scripts/qa/verify-lighthouse-budgets.sh`
- CI workflow: `.github/workflows/lighthouse-ci.yml`
