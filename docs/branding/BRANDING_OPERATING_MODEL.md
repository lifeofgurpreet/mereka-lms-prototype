# Branding Operating Model
_Audience: Platform + Product Engineering • Last updated: 2026-02-08_

This is the canonical workflow for branding changes in Mereka LMS.

## Non-Negotiable Rules

1. `assets/branding/*` is the source input; runtime truth is `infrastructure/tutor/themes/mereka/*`.
2. Any `tutor config save` must be followed by `./infrastructure/tutor/apply-patches.sh`.
   - **Why**: Plugin handles configuration via Tutor hooks (automatic). Script handles asset sync (manual but required).
3. No branding release is complete until both source and live gates pass.
4. Production deploys are GitOps-managed; do not treat direct `kubectl set image` as source-of-truth.
5. Drift is a defect: fix with rebuild+deploy, not by loosening checks.
6. Run only one `tutor images build mfe` at a time; parallel runs cause cache contention and slow/fail builds.
7. `./infrastructure/tutor/apply-patches.sh` is idempotent and required before every MFE/openedx build.
   - **What it does**: Syncs theme assets (logos, fonts, SCSS), sets up theme directories, distributes font files.
   - **What plugin does**: Django settings, MFE footer component, Google Fonts stripping, build config.

## Canonical Workflow

Run this from repo root:

```bash
# 1) Sync brand assets + runtime CSS
./scripts/branding/sync-brand-assets.sh

# 2) Validate branding from source to live
AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod
# includes source-time MFE prerequisite contract check:
# ./scripts/qa/verify-mfe-build-prereqs.sh
```

Optional strict parity mode:

```bash
STRICT_MFE_BRANDING_REV=1 ./scripts/branding/run-branding-gates.sh prod
```

Optional strict service-domain authn mode (`ecommerce.*` + `credentials.*`):

```bash
STRICT_PROXY_AUTHN_BRANDING=1 ./scripts/branding/run-branding-gates.sh prod
```

Optional visual diff mode (screenshot capture + RMSE compare):

```bash
RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 VISUAL_ALLOW_BOOTSTRAP=1 \
./scripts/branding/run-branding-gates.sh prod
```

Validate both production and dev:

```bash
./scripts/branding/run-branding-gates.sh all
```

Install scheduled VPS visual regression checks:

```bash
./scripts/infra/setup-vps-branding-visual-regression-cron.sh
```
Default cron config excludes noisy dynamic/authenticated pages to keep drift alerts actionable.
Override with `VISUAL_EXCLUDE_REGEX` in `var/branding-visual-regression.env` when needed.

## Deploy Contract (Production)

Preferred deployment command:

```bash
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <OPENEDX_TAG> \
  --mfe-tag <MFE_TAG> \
  --apply --commit --push --verify-runtime
```

1. Run source/live branding gates.
2. Build/push images (`openedx`, `openedx-mfe` when changed).
   - Before `tutor images build mfe`, run:
     `scripts/qa/verify-mfe-build-prereqs.sh`
   - After `tutor images build mfe`, verify the built image before push:
     `scripts/qa/verify-mfe-image-branding.sh <image_ref>`
   - CI now enforces this automatically in `.github/workflows/build-tutor-images.yml`
     before MFE image tags are pushed.
3. Update image tags under `deploy/k8s/base`.
4. Commit/push this repo.
5. Update GitOps checkout (`/home/gurpreet/projects/k8s/infrastructure`, typically tracking `BBI-K8`; legacy docs may say `bbi-infrastructure`) in both files:
   - `apps/mereka-lms/base/kustomization.yaml` (`?ref=<sha>`)
   - `apps/mereka-lms/overlays/prod/kustomization.yaml` (openedx/openedx-mfe tags)
6. Run `./scripts/qa/verify-gitops-image-overrides.sh --check-infra`.
7. Verify Argo rollout and rerun branding gates.

## Known Failure Patterns And Correct Fixes

1. **LMS/Studio unbranded on live after merge**
   - Cause: old `openedx` image still running.
   - Fix: rebuild/push `openedx`, bump GitOps ref, rerun `run-branding-gates.sh prod`.

2. **MFE looks old while LMS is correct**
   - Cause: MFE CSS is image-baked; no MFE rebuild.
   - Fix: rebuild/push `openedx-mfe`; enforce `STRICT_MFE_BRANDING_REV=1`.

3. **Studio token/font drift**
   - Cause: Studio Sass entrypoints not synced into Tutor build context.
   - Fix: keep `cms/static/sass/studio-main-v1*.scss` tracked; rerun `apply-patches.sh` before build.

4. **Credentials root returns Page Not Found**
   - Cause: service is API-first.
   - Fix: treat `/health/` + `/admin/login/` as contract; do not require UI landing page at `/`.

5. **Footer/logo regressions**
   - Cause: asset sync drift or override CSS not deployed.
   - Fix: run `sync-brand-assets.sh`, source gate, redeploy image; never patch live pod files.

6. **MFE build flakes on npm network (`ECONNRESET`/`ETIMEDOUT`)**
   - Cause: transient registry/network failures during multi-MFE npm installs.
   - Fix: rerun from a single build session only; `apply-patches.sh` now injects npm retry/timeouts into MFE Dockerfile.
   - Do not start a second `tutor images build mfe` while one is active.

7. **MFE authn serves unthemed CSS even after branded build**
   - Cause: authn `index.html` points to an unbranded bundle hash while branded CSS artifacts exist in the image.
   - Fix:
     1) verify image contract: `scripts/qa/verify-mfe-image-branding.sh <image_ref>`
     2) if failing and rollout is urgent, repair image deterministically:
        `scripts/branding/repair-mfe-authn-branding.sh <source_image> <target_image>`
     3) redeploy with GitOps and rerun strict gate.
   - Prevention (root-cause): `./infrastructure/tutor/apply-patches.sh` now enforces
     authn parity by injecting both `COPY indigo/env.config.jsx /openedx/app/` and
     `COPY indigo/mereka /openedx/app/mereka` into `authn-common` when Tutor template
     drift omits them.

8. **`tutor images build mfe` fails at `authn-prod` with `Can't resolve '@openedx/frontend-plugin-framework'`**
   - Cause: Indigo `env.config.jsx` imports plugin framework, but generated MFE Dockerfile is missing
     dependency install in one or more `*-common` stages.
   - Fix:
     1) rerun `./infrastructure/tutor/apply-patches.sh`
     2) rerun `tutor images build mfe`
     3) validate image contract with `./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest`
   - Prevention: patch script now injects
     `npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'`
     idempotently across generated MFE common stages.

9. **Studio authoring create-flow styles regress silently**
   - Cause: generic Studio CSS checks pass but create-course/create-library selectors drift.
   - Fix: enforce `scripts/qa/verify-studio-authoring-branding.sh` in source and live gates.

10. **Token source drift across repos**
   - Cause: `assets/branding/tokens.css` changes without pinned upstream source metadata.
   - Fix: maintain `assets/branding/tokens.provenance.json`, refresh using
     `scripts/branding/update-token-provenance.sh`, and enforce with
     `scripts/branding/verify-token-drift.sh`.

11. **Studio still imports Google fonts after openedx rebuild**
   - Cause: regex in generated Dockerfile patch block is over-escaped and does not match
     real import lines.
   - Fix:
     1) regenerate with `./infrastructure/tutor/apply-patches.sh`
     2) confirm `tutor_env/env/build/openedx/Dockerfile` uses `fonts[.]googleapis[.]com`
        in both strip blocks
     3) rebuild/push `openedx`, bump GitOps ref/tag, rerun strict branding gates.

12. **Build command appears to "finish" instantly (no real image change)**
   - Cause: `tutor images build openedx` executed without `TUTOR_ROOT` set; Tutor exits early with
     project-root/config error.
   - Fix:
     1) `export TUTOR_ROOT="$(pwd)/tutor_env"`
     2) rerun build
     3) verify local image digest changed before tagging/pushing.

13. **Argo `ComparisonError` with `not our ref` during GitOps rollout**

   - Cause: incorrect pinned SHA in active GitOps repo (`BBI-K8`/`bbi-infrastructure`) (`?ref=<sha>` typo or stale SHA).
   - Fix:
     1) get exact SHA from source repo: `git -C /home/gurpreet/projects/k8s/mereka-lms rev-parse HEAD`
     2) update `apps/mereka-lms/base/kustomization.yaml` with that exact SHA
     3) push and wait for `mereka-lms-local` app to return `Synced/Healthy`.

14. **Argo is `Synced`, but MFE/LMS still run old image tags**
   - Cause: production GitOps overlay (`apps/mereka-lms/overlays/prod/kustomization.yaml`) still pins old tags.
   - Fix:
     1) update overlay tags (`docker.io/overhangio/openedx`, `docker.io/overhangio/openedx-mfe`, transformed MFE entry)
     2) run `./scripts/qa/verify-gitops-image-overrides.sh --check-infra`
     3) push GitOps repo and confirm Argo summary images + live deployment images match.

15. **Visual regression never runs after screenshot capture**
   - Cause: screenshots are captured but no compare step is executed, so drift is only detected manually.
   - Fix:
     1) run `RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 ./scripts/branding/run-branding-gates.sh prod`
     2) install scheduled checks with `scripts/infra/setup-vps-branding-visual-regression-cron.sh`
     3) treat non-zero visual regression exit as release-blocking.

16. **Service-domain authn pages load but CSS/JS assets fail**
   - Cause: authn shell on `ecommerce.*` / `credentials.*` references `/authn/*` paths, but Caddy host blocks
     are only proxying to service backends (not MFE assets).
   - Fix:
     1) add explicit `/authn/*` `reverse_proxy mfe:8002` handlers in both host blocks in
        `deploy/k8s/base/apps/caddy/Caddyfile`
     2) redeploy Caddy via GitOps
     3) enable strict enforcement with `STRICT_PROXY_AUTHN_BRANDING=1` once live checks are green.
     4) do not use `handle_path`; it strips `/authn` and breaks MFE asset paths.
     5) do not use `import proxy "mfe:8002"` inside `handle` blocks; imported `log` directives are invalid there and can crash Caddy.

17. **Forum/ecommerce service roots regress to plain or default pages**
   - Cause: service-domain root landing contract drift in Caddy host blocks.
   - Fix:
     1) keep branded root responses in `deploy/k8s/base/apps/caddy/Caddyfile`
     2) verify with `./scripts/qa/verify-public-branding.sh prod`
     3) enforce via `./scripts/qa/audit-branding-surfaces.sh prod --strict`

18. **kind dev parity drifts from production image tags**
   - Cause: local overlay pins old `openedx`/`openedx-mfe` tags or only one image is loaded into kind.
   - Fix:
     1) keep `deploy/k8s/overlays/local/kustomization.yaml` aligned to current release tags
     2) run `./scripts/infra/apply-kind-overlay.sh` (it loads both images before apply)
     3) verify with `./scripts/qa/verify-public-branding.sh dev`

19. **Caddy crashes after authn host routing edits**
   - Cause: using `import proxy "mfe:8002"` inside `handle /authn/*` blocks; imported `log` is invalid there.
   - Fix:
     1) replace with explicit `reverse_proxy mfe:8002` plus header passthrough
     2) redeploy and confirm `Deployment/caddy` ready
     3) rerun `./scripts/infra/apply-kind-overlay.sh` (dev) or production GitOps rollout + gates

## No DOM Override Policy

**Rule**: All MFE customizations MUST use the Frontend Plugin Framework (FPF) plugin-slot system.
Direct DOM manipulation, monkey-patching, or injecting HTML/JS into MFE bundles is forbidden.

### Approved Override Points

| Surface | Method | Example |
|---------|--------|---------|
| MFE footer | FPF plugin slot `footer.v1` | `MerekaFooter` component via `PLUGIN_SLOTS` |
| MFE header logo | FPF plugin slot `header_logo.v1` | `MerekaHeaderLogo` component via `PLUGIN_SLOTS` |
| MFE styling | SCSS theme override (`mereka.scss`) | `[data-testid*="..."]` selectors preferred |
| LMS templates | Mako template theming (`head-extra.html`, `footer.html`, `header/brand.html`) | Standard Open edX theming mechanism |
| Studio templates | Mako template theming (`head-extra.html`) | Standard Open edX theming mechanism |
| Build-time transforms | `apply-patches.sh` (idempotent, reviewed) | Google Fonts stripping, npm config |

### Forbidden Patterns

| Pattern | Why | Alternative |
|---------|-----|-------------|
| `document.querySelector()` in MFE overrides | Breaks on class rename | Use FPF plugin slot |
| `innerHTML` injection into MFE DOM | XSS risk, brittle | Use React component via slot |
| Patching MFE bundle JS/HTML post-build | Invalidates build hash | Use `env.config.jsx` config |
| Adding `<script>` tags to MFE HTML | CSP violation risk | Use plugin slot or config |
| `[class*="..."]` without `[data-testid*="..."]` fallback | Breaks on Paragon update | Add data-testid dual path |

### Verification

Run `./scripts/qa/verify-no-dom-overrides.sh` to confirm compliance.
This gate runs in CI as job `no-dom-overrides`.

## Non-Plugin Customization Exception Policy

> AC-WC-009: Temporary exceptions for overrides that cannot yet use plugin/theme-first flows.

**Rule**: Every non-plugin customization MUST have an exception entry. Exceptions expire
automatically and become build blockers on their expiry date.

### Exception Format

Each exception must include:

| Field | Required | Description |
|-------|----------|-------------|
| **Item** | Yes | Reference to `PLUGIN_MIGRATION_SURVEY.md` entry (e.g. C1, C3) |
| **Reason** | Yes | Why plugin path is not available today |
| **Owner** | Yes | Person responsible for migration |
| **Expiry** | Yes | Date by which migration must complete (max 6 months) |
| **Fallback** | Yes | What happens if expiry passes without migration |

### Active Exceptions

| Item | Reason | Owner | Expiry | Fallback |
|------|--------|-------|--------|----------|
| C3 (Node cache reuse) | No Tutor hook for pre-npm-install Dockerfile lines | Mereka Platform | 2026-Q4 | Accept slower builds; remove cache reuse |
| C10 (New Relic ENV) | Low priority; plugin hook available but not wired | Mereka Platform | 2026-Q4 | Remove New Relic instrumentation |
| F2 (setup-mfe-branding.sh) | Dev-only; production uses Dockerfile COPY | Mereka Frontend | 2026-Q3 | Document as dev-only in onboarding |

### Exception Lifecycle

1. **Filing**: Add entry to this table with all required fields
2. **Review**: Monthly review during platform eng standup
3. **Expiry**: On expiry date, either migrate or renew with justification
4. **Enforcement**: `scripts/qa/check-forbidden-overrides.sh` warns on expired exceptions
5. **Audit**: `docs/branding/PLUGIN_MIGRATION_SURVEY.md` tracks full inventory

### Renewal Rules

- Maximum 2 renewals per exception (total 18 months from first filing)
- Each renewal requires written justification in PR description
- Renewed exceptions must update the expiry date in this table

## What Was Hacky And How We Avoid It

- Hacky pattern: manual one-off checks run ad-hoc by different agents.
  - Standard now: `scripts/branding/run-branding-gates.sh`.
- Hacky pattern: assuming prod and repo are in sync.
  - Standard now: revision markers + strict parity option.
- Hacky pattern: updating docs after incidents only.
  - Standard now: update `AGENTS.md` + this doc in every branding incident/fix PR.

## Ownership And Cadence

- **Every branding-affecting PR**: run source gate at minimum.
- **Every production rollout**: run `run-branding-gates.sh prod`.
- **Daily/shift checks**: run `run-branding-gates.sh prod` (can disable screenshots by default).
- **Scheduled visual drift checks**: keep VPS cron active via
  `scripts/infra/setup-vps-branding-visual-regression-cron.sh`.

## CI Enforcement

- PR/push source preflight: `.github/workflows/ci.yml` job `branding-preflight`
  - Runs: `RUN_LIVE_GATE=0 BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod`
- Scheduled/runtime strict checks: `.github/workflows/public-health-check.yml`
  - Runs prod with strict revision parity:
    `STRICT_MFE_BRANDING_REV=1 AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod`
  - Uploads logs from `var/ci/*.log` as workflow artifacts.
  - Any strict parity failure is a release blocker until deploy drift is corrected.

## Plugin Slot Migration

_Added: 2026-02-18 (bead 2dcy.6 / AC-FRONT-064)_

### Slot IDs in Use

| Slot ID | What It Replaces | Registration | Fallback Strategy |
|---------|-----------------|--------------|-------------------|
| `footer_slot` | Default Indigo/OpenedX `<Footer />` component | `mereka_lms.py` `PLUGIN_SLOTS.add_item` | `apply-patches.sh` `RenderWidget: <MerekaFooter />` string replacement |
| `header_logo_slot` | Default MFE header bar logo | `mereka_lms.py` `PLUGIN_SLOTS.add_item` | Scoped `.mereka-header-logo` fallback sizing in `mereka.scss` |
| `learner_dashboard.sidebar.v1` | Dashboard sidebar (append mode) | `mereka_lms.py` `PLUGIN_SLOTS.add_item` | SCSS scoped layout rules under `[data-testid*="learner-dashboard"]` (RISK: HIGH) |

### Fallback Strategy

When `tutormfe.hooks.PLUGIN_SLOTS` is not available (older Tutor versions), the plugin falls back to:

1. **footer_slot fallback**: `apply-patches.sh` replaces `RenderWidget: <Footer />` with `RenderWidget: <MerekaFooter />` in the generated `env.config.jsx`. This is a structural string-rewrite that is kept with a `# MIGRATED-TO-SLOT:` comment for traceability.
2. **learner_dashboard.sidebar.v1 fallback**: SCSS scoped under `[data-testid*="learner-dashboard"]` provides layout rules. Tagged `RISK: HIGH` in `mereka.scss`.

The `_PLUGIN_SLOTS_AVAILABLE` boolean in `mereka_lms.py` indicates whether the canonical slot path is active. Check at runtime with:

```bash
grep '_PLUGIN_SLOTS_AVAILABLE' infrastructure/tutor/plugins/mereka_lms.py
```

### Migration Status Table

| Customization | Status | Slot ID | Notes |
|---------------|--------|---------|-------|
| Footer component | MIGRATED (dual-path) | `footer_slot` | Canonical; fallback path kept for Tutor compat |
| Header logo | MIGRATED (dual-path) | `header_logo_slot` | Canonical; component via slot |
| Dashboard sidebar CTA | PARTIAL (slot + fallback) | `learner_dashboard.sidebar.v1` | Slot drives secondary surface; compatibility SCSS retained |
| Authn card styling | MIGRATED (dual-path) | `org.openedx.frontend.authn.login_component.v1` | Slot active; compatibility CSS retained |
| Learning MFE layout | NOT MIGRATED | — | No upstream slot; P2 upstream request filed |
| Course card grid/list | NOT MIGRATED | — | No upstream slot; SCSS fallback only |

### Regression Check Procedure

After any slot or SCSS change affecting authn or learner-dashboard routes:

1. Verify syntax: `bash -n infrastructure/tutor/apply-patches.sh`
2. Verify slot wiring: `./scripts/qa/verify-mfe-footer-slot.sh`
3. Verify selector compliance: `./scripts/qa/verify-mfe-selector-hardening.sh`
4. Verify no DOM overrides: `./scripts/qa/verify-no-dom-overrides.sh`
5. Run source branding gate: `RUN_LIVE_GATE=0 ./scripts/branding/run-branding-gates.sh prod`
6. For live cluster checks: `./scripts/qa/verify-mfe-footer-slot-migration.sh`

For authn route spot checks, look for:
- `[data-testid*="login-page"]` or `[data-testid*="authn"]` in rendered DOM
- `MerekaFooter` in `env.config.jsx` (verify via `grep MerekaFooter tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`)

For learner dashboard spot checks:
- `[data-testid*="learner-dashboard"]` in rendered DOM
- Dashboard sidebar renders without layout collapse

### Rollback Procedure

If slot injection fails (MFE build error or runtime slot not rendering):

1. **Immediate**: Revert to CSS-only fallback — SCSS selectors in `mereka.scss` already cover all high-risk surfaces with `RISK: HIGH` tags. No build change needed.
2. **footer_slot failure**: The `apply-patches.sh` fallback (string replacement) is always active. Verify with `grep 'MerekaFooter' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`.
3. **Full rollback**: Set `_PLUGIN_SLOTS_AVAILABLE = False` in `mereka_lms.py` (by ensuring `PLUGIN_SLOTS` import fails gracefully via the existing `try/except ImportError` block).
4. Rebuild MFE image: `tutor images build mfe`
5. Verify: `./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest`

## Related Documents

- `docs/branding/BRANDING_GUARDRAILS.md`
- `docs/branding/BRANDING_ROADMAP.md`
- `docs/branding/BRANDING_INCIDENT_TEMPLATE.md`
- `docs/BRANDING.md`
- `docs/operations/THEME_DEPLOYMENT.md`
- `docs/operations/OPENEDX_HOSTNAMES.md`
- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
- `docs/operations/FOOTER_VARIANT_MATRIX.md`
