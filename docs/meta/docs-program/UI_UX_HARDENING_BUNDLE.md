# UI/UX Hardening Bundle

**Bead**: 8jao.25 / mereka-lms-115d.25
**Last updated**: 2026-02-18
**Spec**: `bead-115d25`
**ACs**: AC-HB-001 through AC-HB-006

---

## Overview

This document is the single authoritative reference for the UI/UX hardening lane. It defines:

- Visual regression baseline (10+ critical routes) and the baseline refresh playbook
- A11y gate configuration (focus, landmark, contrast) and route-level exception policy with owners
- Performance budgets (bundle size, LCP proxy checks, JS error budget thresholds)
- Weekly trend report template
- Triage template for failures
- Exception register for intentional cosmetic deviations with rollback safety markers

Related documents:
- `docs/runbooks/operations/VISUAL_SMOKE_BASELINE.md` — visual smoke baseline per environment
- `docs/runbooks/operations/VISUAL_REGRESSION_RUNBOOK.md` — visual regression runbook
- `docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md` — checkpoint matrix (5 routes × 3 domains)
- `docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md` — contrast and focus-visible gate details
- `docs/policies/architecture/PERFORMANCE_BUDGETS.md` — full Web Vitals + cache-control policy

---

## AC-HB-001: Visual Regression Baseline

### Critical Route Inventory (10+ routes)

The following routes form the deterministic authenticated visual regression baseline.
All must be captured in an authenticated browser session before any production deploy.

| # | Route | MFE / Surface | Expected State |
|---|-------|---------------|----------------|
| 1 | `/learner-dashboard/` | learner-dashboard MFE | Enrolled courses, Mereka brand header |
| 2 | `/learning/course-v1:<org>+<course>+<run>/home` | frontend-app-learning | Course home, progress sidebar |
| 3 | `/account/` | account-settings MFE | Account Settings form, Mereka footer |
| 4 | `/gradebook/` | gradebook MFE | Grade table, no Open edX default footer |
| 5 | `/profile/<username>` | profile MFE | Profile page, avatar, bio field |
| 6 | `/authn/login` | authn MFE | Mereka-branded login page, SSO button |
| 7 | `/discussions/` | discussions MFE | Forum thread list, landmark nav |
| 8 | `/program/<uuid>/` | learner-dashboard (program tab) | Program progress card |
| 9 | `/search/` | course-discovery MFE | Search bar, course grid |
| 10 | `/course-authoring/home` | course-authoring MFE | Studio overview (authenticated staff) |
| 11 | `/learner-dashboard/` (biji-biji.com) | learner-dashboard MFE | biji-biji tenant branding |
| 12 | `/learner-dashboard/` (academy.biji-biji.com) | learner-dashboard MFE | academy subdomain tenant branding |

**Authenticated baseline**: Screenshots must be taken with a learner session cookie.
A `VISUAL_REGRESSION_SESSION_COOKIE` environment variable must be injected at capture time.

### Screenshot Naming Convention

```
baseline/<route-slug>/<tenant>/<timestamp>.png
# Examples:
baseline/learner-dashboard/mereka/2026-02-18T10-00-00Z.png
baseline/account/biji-biji/2026-02-18T10-00-00Z.png
```

Tenant values: `mereka`, `biji-biji`, `academy-biji-biji`.

### RMSE Diff Threshold Policy

| Deviation class | RMSE threshold | Action |
|----------------|---------------|--------|
| Pass | ≤ 5.0 | No action required |
| Advisory | 5.1 – 10.0 | Log WARN, notify owner |
| Fail | > 10.0 | Block release, open triage |

Pixel-level diff tool: `pixelmatch` (Node) or `Pillow`-based `ImageChops.difference` (Python).
RMSE is computed over the full viewport (1280 × 800).

### Baseline Refresh Playbook

Use this procedure whenever the intended UI changes (new branding, layout updates, intentional copy changes):

1. **Announce**: Create a PR with the description `[baseline-refresh]` in the title.
2. **Review**: At least one design owner (`@branding-team`) must approve the diff.
3. **Capture**: Run the capture script in authenticated mode:
   ```bash
   VISUAL_REGRESSION_SESSION_COOKIE=<cookie> \
   CAPTURE_MODE=baseline \
   ./scripts/qa/capture-branding-screenshots.sh
   ```
4. **Commit**: Commit the new baselines under `baseline/` with a message:
   ```
   chore(visual-baseline): refresh authenticated route screenshots [baseline-refresh]
   ```
5. **Update register**: Add an entry to the [Exception Register](#ac-hb-006-exception-register) if the change is intentional but deviates from the prior baseline.
6. **Verify**: Run `./scripts/qa/verify-visual-smoke-baseline.sh` — all checks must pass before merging.
7. **Tag**: Create a git tag `visual-baseline-YYYY-MM-DD` on the merge commit.

---

## AC-HB-002: A11y Gate

### Gate Configuration

The a11y gate covers three dimensions on every critical route:

#### Focus / Focus-Visible

All interactive elements (buttons, links, form inputs) must have a visible focus indicator that passes WCAG 2.1 SC 2.4.7 (Focus Visible) and SC 2.4.11 (Focus Appearance, AAA advisory).

Requirements:
- No `outline: none` or `outline: 0` without an equivalent `box-shadow` or `:focus-visible` replacement.
- The `--mereka-mfe-focus` CSS token must be defined in `mfe/mereka.scss`.
- `.btn-primary` and `.form-control` must have `:focus` rules in MFE SCSS.

Gate script: `scripts/qa/verify-a11y-contrast-focus.sh`

#### Landmark Regions

All routes must declare the ARIA landmark regions:

| Landmark | Element / Role | Required on |
|----------|---------------|-------------|
| `role="banner"` | `<header>` | All routes |
| `role="navigation"` | `<nav>` | All routes |
| `role="main"` | `<main>` | All routes |
| `role="contentinfo"` | `<footer>` | All routes |

Gate script: `scripts/qa/verify-a11y-authenticated-routes.sh`

#### Contrast

WCAG AA contrast thresholds:

| Text type | Minimum ratio |
|-----------|--------------|
| Normal text (< 18px regular, < 14px bold) | 4.5 : 1 |
| Large text (≥ 18px regular, ≥ 14px bold) | 3.0 : 1 |
| UI components / graphical objects | 3.0 : 1 |

Checked token pairs: `ink-900/surface`, `ink-700/surface`, `ink-500/surface`, `blue/surface`, `teal/surface`, `white/magenta`, `white/blue`, `forest/surface`, `burgundy/surface`.

Gate script: `scripts/qa/verify-a11y-contrast-focus.sh`

### Route-Level Exception Policy with Owners

Exceptions to the a11y gate must be registered below. Only exceptions listed here may appear as `WARN` in CI; all unlisted failures are `FAIL`.

| Route | Dimension | Exception reason | Owner | Expiry |
|-------|-----------|-----------------|-------|--------|
| `/discussions/` | Landmark | Forum v2 (Python) wraps content in a non-semantic div; landmark injection pending upstream fix | `@platform-team` | 2026-06-30 |
| `/course-authoring/*` | Focus | Studio-side Paragon buttons do not yet carry `:focus-visible`; Q2 2026 Paragon upgrade required | `@frontend-team` | 2026-06-30 |

To add a new exception:
1. Open a PR with `[a11y-exception]` in the title.
2. Obtain approval from `@a11y-reviewer` and the route owner.
3. Add an entry to the table above with an expiry no more than 90 days out.
4. Set a calendar reminder to review before expiry.

---

## AC-HB-003: Performance Budgets

### Bundle Size Thresholds

| Artifact | Budget (gzipped) | Enforcement |
|---------|-----------------|-------------|
| Main bundle (initial JS) | 500 KB | FAIL above threshold |
| Largest individual chunk | 250 KB | WARN above threshold |
| Total initial load (JS + CSS) | 700 KB | WARN above threshold |
| CSS main bundle | 100 KB | WARN above threshold |

Tooling: `webpack-bundle-analyzer`, `bundlesize` npm package, or `size-limit`.

### LCP Proxy Checks

Because we cannot run a full Lighthouse audit in CI (requires a live browser), we use offline LCP proxy checks:

| Proxy metric | Threshold | Rationale |
|-------------|-----------|-----------|
| Time To First Byte (TTFB) | ≤ 600 ms (p75) | Caddy → LMS response time |
| Static asset cache hit rate | ≥ 90% | Confirmed via Caddy `header` Cache-Control policies |
| Hashed asset `max-age` | 31 536 000 s (1 year) | Verified in `Caddyfile` |
| HTML `no-cache` policy | Present | Prevents stale SPA shells |

LCP target (real-user): ≤ 2.5 s (p75) — measured via Grafana / Sentry Performance.

Gate script: `scripts/qa/verify-performance-budget.sh`

### JS Error Budget Thresholds

| Metric | Good | Warning | Failing |
|--------|------|---------|---------|
| JS error rate (Sentry) | < 0.1 % of sessions | 0.1 – 1 % | > 1 % |
| Unhandled promise rejections | < 5 per deploy window | 5 – 20 | > 20 |
| Error budget burn rate (1 h) | < 2× | 2 – 5× | > 5× |

Gate script: `scripts/qa/check-error-budget-gate.sh`

The error budget is defined in `scripts/qa/verify-error-budget.sh` and sourced from the Prometheus `slo_error_budget_remaining` recording rule.

### Regression Check Protocol

Before any deploy that touches MFE code or Caddy config:

1. Run `./scripts/qa/verify-performance-budget.sh` (offline check).
2. If deploying to production, trigger a Lighthouse run via `smoke-test` and compare against the p75 LCP baseline.
3. If bundle size exceeds threshold: run `webpack-bundle-analyzer` to identify the regression, then either optimise or update the budget with a documented reason.

---

## AC-HB-004: CI Integration

The following table maps each gate script to its CI job:

| Gate | Script | CI Job |
|------|--------|--------|
| Visual regression baseline | `verify-visual-parity-checkpoints.sh` | `visual-parity-checkpoints` |
| Visual smoke baseline | `verify-visual-smoke-baseline.sh` | `visual-smoke-baseline` |
| A11y contrast + focus | `verify-a11y-contrast-focus.sh` | `a11y-contrast-focus` |
| A11y authenticated routes | `verify-a11y-authenticated-routes.sh` | `a11y-authenticated-routes` |
| A11y tenant branding | `verify-a11y-tenant-branding.sh` | `a11y-tenant-branding` |
| Performance budget | `verify-performance-budget.sh` | `performance-budget` |
| Error budget | `verify-error-budget.sh` | `verify-static` (batch) |
| UI/UX hardening bundle | `verify-ui-ux-hardening-bundle.sh` | `ui-ux-hardening-bundle` |

### Actionable Failure Reasons

Every CI failure must include a non-ambiguous failure reason. Gate scripts use the following pattern:

```
  FAIL  AC-HB-001: visual regression baseline section missing from UI_UX_HARDENING_BUNDLE.md
```

The failure message must:
- Identify the AC (e.g. `AC-HB-001`)
- State what was expected (e.g. "section missing")
- State where to fix it (e.g. "UI_UX_HARDENING_BUNDLE.md")

The CI artifact is uploaded to `var/ui-ux-hardening-bundle-gate.txt` on every run.

---

## AC-HB-005: Weekly Trend Reports

### Trend Report Template

Use this template to produce a weekly trend report (every Monday, covering the prior week):

```markdown
# UI/UX Hardening Trend Report — Week of YYYY-MM-DD

**Gates run this week**: N
**Total checks**: N (PASS: X | FAIL: Y | WARN: Z)

## Visual Regression
- Routes checked: N
- Baselines refreshed: N
- RMSE failures: N (list routes)

## A11y
- Contrast PASS rate: N%
- Focus-visible PASS rate: N%
- Landmark PASS rate: N%
- New exceptions requested: N

## Performance
- Bundle size: N KB (gzipped) — delta from prior week: ±N KB
- LCP proxy: TTFB p75 = N ms
- JS error rate: N% — delta: ±N%
- Error budget remaining: N%

## Exception Register Activity
- New exceptions: N
- Exceptions expiring within 14 days: N (list)

## Action Items
- [ ] Owner / deadline / AC reference
```

### Trend Metrics

Track the following weekly metrics in a shared sheet or Grafana dashboard:

| Metric | Source | Target trend |
|--------|--------|-------------|
| PASS rate (all gates) | CI run summary | ↑ each sprint |
| FAIL count | CI run summary | ↓ to 0 |
| WARN count | CI run summary | Stable or ↓ |
| Open exceptions | Exception register | ≤ 5 at any time |
| Bundle size (gzipped) | `verify-performance-budget.sh` | ≤ 500 KB |
| JS error rate | Sentry / Prometheus | < 0.1 % |

---

## Triage Template

When a gate failure appears in CI, use this template to open a triage issue:

```markdown
## UI/UX Gate Failure Triage

**Date**: YYYY-MM-DD
**CI run**: <link>
**Failure type**: [ ] Visual Regression  [ ] A11y  [ ] Performance  [ ] CI Wiring
**AC**: AC-HB-00N
**Affected route(s)**: /path/to/route
**Failure message**:
  FAIL  <exact message from gate output>

**Root cause**:
<!-- One of: accidental regression | deliberate change (needs baseline refresh) | flaky environment | CI misconfiguration -->

**Owner**: @<github-handle>
**Next step**: <!-- e.g. "Fix CSS", "Refresh baseline", "Add exception register entry" -->
**Resolution deadline**: YYYY-MM-DD
**Rollback required**: [ ] Yes  [ ] No
```

**Triage SLA**: All `FAIL` items must be triaged within 1 business day of appearing in CI.

---

## AC-HB-006: Exception Register

The exception register tracks intentional cosmetic deviations from the visual baseline or a11y/performance gates. Every entry is rollback-safe: it documents what the deviation is, why it is intentional, who approved it, and when it should be reviewed.

### Rollback Safety Policy

- All entries must include a `rollback-safe: yes` marker (see table below).
- "Rollback-safe" means that reverting the deviation (restoring the prior baseline) will not break user journeys or accessibility for other users.
- Entries with `rollback-safe: no` require a separate architectural review before being merged.

### Current Exception Entries

| ID | Gate | Route | Deviation | Reason | Owner | Approved by | Expiry | Rollback-safe |
|----|------|-------|-----------|--------|-------|-------------|--------|---------------|
| EX-001 | Visual | `/discussions/` | Forum header uses Open edX grey (#3d3d3d) instead of Mereka ink-900 | Forum v2 CSS ships upstream; tenant override pending Q2 2026 theme uplift | `@platform-team` | `@design-lead` | 2026-06-30 | yes |
| EX-002 | A11y / Contrast | `/authn/login` placeholder text | `ink-300` on `surface` = 3.2 : 1 (below 4.5 : 1 for normal text) | Placeholder text is purely decorative; real label meets 4.5 : 1 | `@frontend-team` | `@a11y-reviewer` | 2026-06-30 | yes |
| EX-003 | Performance | All routes | Bundle size budget advisory WARN: initial load = 520 KB (> 500 KB) | Q1 2026 Paragon upgrade added 22 KB; optimisation scheduled for Q2 2026 sprint | `@frontend-team` | `@tech-lead` | 2026-04-30 | yes |

### Adding a New Exception

1. Open a PR titled `[cosmetic-exception] brief description`.
2. Add an entry to the table above with all fields populated.
3. Get approval from the relevant gate owner (see Gate→Owner mapping in AC-HB-004).
4. Set expiry to no more than 90 days.
5. Add a calendar reminder for 7 days before expiry to reassess.
6. Once the underlying issue is resolved, remove the entry and update the baseline.

### Reviewing Expiring Exceptions

Run this query to list entries expiring within 14 days:

```bash
python3 -c "
import re, datetime
text = open('docs/meta/docs-program/UI_UX_HARDENING_BUNDLE.md').read()
today = datetime.date.today()
for m in re.finditer(r'\| (EX-\d+) \|.*?\| (\d{4}-\d{2}-\d{2}) \| (yes|no) \|', text):
    eid, expiry, safe = m.group(1), m.group(2), m.group(3)
    exp_date = datetime.date.fromisoformat(expiry)
    delta = (exp_date - today).days
    if delta <= 14:
        print(f'{eid}: expires {expiry} ({delta} days) rollback-safe={safe}')
"
```

---

## Quick Reference

```bash
# Run the full hardening bundle gate (offline)
./scripts/qa/verify-ui-ux-hardening-bundle.sh

# Run with live cluster probes
UI_HARDENING_LIVE=1 UI_HARDENING_DOMAIN=academyv2.mereka.io \
  ./scripts/qa/verify-ui-ux-hardening-bundle.sh

# Run a11y gate only
./scripts/qa/verify-a11y-contrast-focus.sh

# Run visual regression verification
./scripts/qa/verify-visual-parity-checkpoints.sh

# Run performance budget gate
./scripts/qa/verify-performance-budget.sh

# Run error budget gate
./scripts/qa/check-error-budget-gate.sh
```

---

## Cross-References

| Document | Purpose |
|----------|---------|
| `docs/runbooks/operations/VISUAL_SMOKE_BASELINE.md` | Per-environment visual smoke baseline |
| `docs/runbooks/operations/VISUAL_REGRESSION_RUNBOOK.md` | Visual regression investigation runbook |
| `docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md` | 5-route × 3-domain checkpoint matrix |
| `docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md` | Contrast gate WCAG AA thresholds |
| `docs/runbooks/operations/A11Y_TENANT_BRANDING_GATE.md` | Tenant a11y gate |
| `docs/policies/architecture/PERFORMANCE_BUDGETS.md` | Web Vitals thresholds, cache-control policy |
| `docs/runbooks/operations/BRANDING_RELEASE_RUNBOOK.md` | Branding release checklist |
