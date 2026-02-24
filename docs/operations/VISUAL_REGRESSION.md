# Visual Regression Baseline Governance
_Audience: Platform Eng • Last updated: 2026-02-24_

Defines the approval process for visual baseline images, drift detection, and
integration with the Tutor/MFE upgrade cycle.

---

## 1. Why This Exists

Tutor config changes, MFE rebuilds, and theme updates can silently break the
learner-facing UI. Baseline governance creates a documented, reviewable record
of what "correct" looks like so regressions are caught before they reach
production.

---

## 2. Baseline Storage

All baseline screenshots live under:

```
visual-baselines/
  baselines.json              # Metadata index (required fields below)
  screenshots/
    login--desktop.png
    login--mobile.png
    dashboard--desktop.png
    dashboard--mobile.png
    course--desktop.png
    course--mobile.png
    footer--desktop.png
    footer--mobile.png
```

**Rules:**
- `visual-baselines/` is committed to git. Screenshots are binary blobs; keep
  them under 500 KB each (compress with `pngquant` or `optipng` before commit).
- `baselines.json` is the source of truth. The verification script validates it.
- Never overwrite a baseline without an approved PR (see Section 3).

---

## 3. Baseline Approval Workflow

### Who approves

| Change type | Required approver |
|-------------|-------------------|
| Routine upgrade (patch/minor Tutor) | Any Platform Eng team member |
| Major Tutor / MFE version bump | Platform Eng lead (`gurpreet@biji-biji.com`) |
| Branding or theme overhaul | Platform Eng lead + Academic Ops sign-off |
| Footer / legal copy changes | Platform Eng lead + stakeholder sign-off |

### Process

1. **Capture** — Run `scripts/qa/capture-branding-screenshots.sh` against the
   updated environment to produce candidate screenshots.
2. **Diff** — Run `scripts/qa/visual-regression-branding.sh prod` (or `dev`) to
   produce RMSE diffs. Review `var/screenshots-diff/` visually.
3. **PR** — Open a PR updating `visual-baselines/screenshots/` and
   `visual-baselines/baselines.json`. Include diff images as PR attachments.
4. **Review** — Approver inspects the diff images and confirms the change is
   intentional (no unintended regressions).
5. **Merge** — After approval, merge to `main`. The new screenshots become the
   next baseline.
6. **Verify** — After merge run `scripts/qa/verify-visual-baselines.sh` to
   confirm the metadata file is valid.

### When to update baselines (mandatory)

- After any `tutor images build` that changes rendered HTML/CSS.
- After `make branding-sync` when new brand assets are applied.
- After MFE npm dependency upgrades that affect styled components.
- After Tutor major/minor version upgrades (Ulmo → next named release).
- After Caddy or nginx config changes that affect static asset serving.

---

## 4. Percy / Chromatic-Style Workflow (Future Adoption)

We do not currently use Percy or Chromatic. When we do, the workflow maps as
follows:

| Current manual step | Percy/Chromatic equivalent |
|---------------------|---------------------------|
| `capture-branding-screenshots.sh` | SDK screenshot upload in CI |
| `visual-regression-branding.sh` | Automated diff in PR check |
| PR review with diff images | Approve/reject snapshots in web UI |
| `baselines.json` update | Accepted snapshots become new baseline |

Until a tool is adopted, the manual process in Section 3 is authoritative.
The `baselines.json` schema is designed to be forward-compatible with Percy's
snapshot naming convention (page + viewport + git SHA).

---

## 5. Integration with Tutor / MFE Upgrade Cycle

Add the following steps to the upgrade checklist
(`docs/operations/RELEASE_CHECKLIST.md`):

```
[ ] Before upgrade: run capture-branding-screenshots.sh → save as pre-upgrade baseline
[ ] After upgrade: run capture-branding-screenshots.sh again
[ ] Run visual-regression-branding.sh to diff pre vs post
[ ] Review diffs; if intentional update baselines.json + screenshots in PR
[ ] Run verify-visual-baselines.sh — must PASS before promoting to prod
```

The `verify-visual-baselines.sh` script is a hard gate: it will exit non-zero
if baselines are missing, metadata is incomplete, or screenshots are older than
`MAX_BASELINE_AGE_DAYS` (default 90 days).

---

## 6. Manual Visual QA Checklist

Run this checklist after every upgrade and before every production release.

### 6.1 Login Page (`/login`)

- [ ] Mereka logo renders at correct size and aspect ratio (no stretch/crop).
- [ ] Background image / color matches brand.
- [ ] "Sign in" button uses brand primary color.
- [ ] Social auth buttons (Google, etc.) are visible and aligned.
- [ ] No broken image placeholders (`alt` fallback text only).
- [ ] Mobile (375 px): form fields are full-width and not clipped.

### 6.2 Learner Dashboard (`/dashboard`)

- [ ] Header shows logo and nav links correctly.
- [ ] "My Courses" cards render with thumbnails.
- [ ] Course progress bars are visible.
- [ ] No console errors (open DevTools → Console, reload, check for red errors).
- [ ] Mobile: cards stack vertically, no horizontal overflow.

### 6.3 Course Page (`/courses/<id>/courseware`)

- [ ] Sidebar navigation renders with unit titles.
- [ ] Video player loads (even if content is a placeholder).
- [ ] Breadcrumb shows correct course > section > unit hierarchy.
- [ ] Footer is visible at bottom of content.
- [ ] Mobile: sidebar collapses to hamburger menu; content area is full-width.

### 6.4 Footer

- [ ] Footer text matches `SITE_VARIANTS` / `SiteConfiguration` data contract
  (see `docs/operations/MULTISITE_GOVERNANCE.md` §3).
- [ ] All footer links resolve (no 404s on hover-inspect).
- [ ] Copyright year is current.
- [ ] Mobile: footer stacks to a single column.

### 6.5 Mobile Viewport (375 × 812 px — iPhone SE baseline)

Test all pages above at 375 px width. Additional checks:

- [ ] No element overflows the viewport horizontally (no side-scroll).
- [ ] Touch targets are ≥ 44 px tall.
- [ ] Font sizes are readable (≥ 14 px body, ≥ 16 px inputs).
- [ ] Images scale down correctly (`max-width: 100%`).

---

## 7. Screenshot Comparison Workflow (Before / After)

```bash
# 1. Capture before (save to a named directory)
SCREENSHOT_DIR=var/screenshots/prod/before ./scripts/qa/capture-branding-screenshots.sh prod

# 2. Apply upgrade / change

# 3. Capture after
SCREENSHOT_DIR=var/screenshots/prod/after ./scripts/qa/capture-branding-screenshots.sh prod

# 4. Diff
./scripts/qa/visual-regression-branding.sh prod \
  --baseline var/screenshots/prod/before \
  --candidate var/screenshots/prod/after

# 5. Inspect diff images
ls var/screenshots-diff/prod/

# 6. If diffs are intentional, update baselines
cp var/screenshots/prod/after/*.png visual-baselines/screenshots/
# Then update visual-baselines/baselines.json (capture_date, git_sha, approved_by)

# 7. Verify
./scripts/qa/verify-visual-baselines.sh
```

---

## 8. Drift Alerts

### Age-based alert

`verify-visual-baselines.sh` fails if any baseline is older than
`MAX_BASELINE_AGE_DAYS` (default 90). Wire this into your CI/CD pipeline or
run it as part of `make qa-smoke`:

```yaml
# .github/workflows/qa.yml (example)
- name: Visual baseline governance
  run: ./scripts/qa/verify-visual-baselines.sh
  env:
    MAX_BASELINE_AGE_DAYS: 90
```

### Upgrade-triggered check

The `verify-deployment-gate.sh` pre-prod gate should include visual baseline
verification once the baseline set is populated. Until then, run manually:

```bash
./scripts/qa/verify-visual-baselines.sh
```

---

## 9. `baselines.json` Schema

```json
{
  "schema_version": 1,
  "baselines": [
    {
      "page": "login",
      "viewport": "desktop",
      "filename": "login--desktop.png",
      "capture_date": "2026-02-24",
      "approved_by": "gurpreet@biji-biji.com",
      "git_sha": "abc1234"
    }
  ]
}
```

Required fields per entry:

| Field | Description |
|-------|-------------|
| `page` | Logical page name (`login`, `dashboard`, `course`, `footer`) |
| `viewport` | `desktop` or `mobile` |
| `filename` | PNG filename under `visual-baselines/screenshots/` |
| `capture_date` | ISO 8601 date (`YYYY-MM-DD`) |
| `approved_by` | Email of the approver |
| `git_sha` | Short SHA of the commit where the baseline was captured |

---

## 10. Related Files

| File | Purpose |
|------|---------|
| `scripts/qa/capture-branding-screenshots.sh` | Capture screenshots |
| `scripts/qa/visual-regression-branding.sh` | Pixel-level diff (ImageMagick RMSE) |
| `scripts/qa/verify-visual-baselines.sh` | Governance gate (metadata + age check) |
| `visual-baselines/baselines.json` | Metadata index |
| `visual-baselines/screenshots/` | Committed baseline PNG files |
| `docs/operations/MULTISITE_GOVERNANCE.md` | Branding + theme governance |
| `docs/operations/RELEASE_CHECKLIST.md` | Release gate checklist |
