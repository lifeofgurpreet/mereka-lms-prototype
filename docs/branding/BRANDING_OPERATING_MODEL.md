# Branding Operating Model
_Audience: Platform + Product Engineering • Last updated: 2026-02-07_

This is the canonical workflow for branding changes in Mereka LMS.

## Non-Negotiable Rules

1. `assets/branding/*` is the source input; runtime truth is `infrastructure/tutor/themes/mereka/*`.
2. Any `tutor config save` must be followed by `./infrastructure/tutor/apply-patches.sh`.
3. No branding release is complete until both source and live gates pass.
4. Production deploys are GitOps-managed; do not treat direct `kubectl set image` as source-of-truth.
5. Drift is a defect: fix with rebuild+deploy, not by loosening checks.
6. Run only one `tutor images build mfe` at a time; parallel runs cause cache contention and slow/fail builds.
7. `./infrastructure/tutor/apply-patches.sh` is idempotent and required before every MFE/openedx build.

## Canonical Workflow

Run this from repo root:

```bash
# 1) Sync brand assets + runtime CSS
./scripts/branding/sync-brand-assets.sh

# 2) Validate branding from source to live
AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod
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

1. Run source/live branding gates.
2. Build/push images (`openedx`, `openedx-mfe` when changed).
   - After `tutor images build mfe`, verify the built image before push:
     `scripts/qa/verify-mfe-image-branding.sh <image_ref>`
   - CI now enforces this automatically in `.github/workflows/build-tutor-images.yml`
     before MFE image tags are pushed.
3. Update image tags under `deploy/k8s/base`.
4. Commit/push this repo.
5. Update pinned `?ref=<sha>` in `bbi-infrastructure/apps/mereka-lms/base/kustomization.yaml`.
6. Verify Argo rollout and rerun branding gates.

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

8. **Studio authoring create-flow styles regress silently**
   - Cause: generic Studio CSS checks pass but create-course/create-library selectors drift.
   - Fix: enforce `scripts/qa/verify-studio-authoring-branding.sh` in source and live gates.

9. **Token source drift across repos**
   - Cause: `assets/branding/tokens.css` changes without pinned upstream source metadata.
   - Fix: maintain `assets/branding/tokens.provenance.json`, refresh using
     `scripts/branding/update-token-provenance.sh`, and enforce with
     `scripts/branding/verify-token-drift.sh`.

10. **Studio still imports Google fonts after openedx rebuild**
   - Cause: regex in generated Dockerfile patch block is over-escaped and does not match
     real import lines.
   - Fix:
     1) regenerate with `./infrastructure/tutor/apply-patches.sh`
     2) confirm `tutor_env/env/build/openedx/Dockerfile` uses `fonts[.]googleapis[.]com`
        in both strip blocks
     3) rebuild/push `openedx`, bump GitOps ref/tag, rerun strict branding gates.

11. **Build command appears to "finish" instantly (no real image change)**
   - Cause: `tutor images build openedx` executed without `TUTOR_ROOT` set; Tutor exits early with
     project-root/config error.
   - Fix:
     1) `export TUTOR_ROOT="$(pwd)/tutor_env"`
     2) rerun build
     3) verify local image digest changed before tagging/pushing.

12. **Argo `ComparisonError` with `not our ref` during GitOps rollout**
   - Cause: incorrect pinned SHA in `bbi-infrastructure` (`?ref=<sha>` typo or stale SHA).
   - Fix:
     1) get exact SHA from source repo: `git -C /home/gurpreet/projects/k8s/mereka-lms rev-parse HEAD`
     2) update `apps/mereka-lms/base/kustomization.yaml` with that exact SHA
     3) push and wait for `mereka-lms-local` app to return `Synced/Healthy`.

13. **Visual regression never runs after screenshot capture**
   - Cause: screenshots are captured but no compare step is executed, so drift is only detected manually.
   - Fix:
     1) run `RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 ./scripts/branding/run-branding-gates.sh prod`
     2) install scheduled checks with `scripts/infra/setup-vps-branding-visual-regression-cron.sh`
     3) treat non-zero visual regression exit as release-blocking.

14. **Service-domain authn pages load but CSS/JS assets fail**
   - Cause: authn shell on `ecommerce.*` / `credentials.*` references `/authn/*` paths, but Caddy host blocks
     are only proxying to service backends (not MFE assets).
   - Fix:
     1) add `handle /authn/* { import proxy "mfe:8002" }` in both host blocks in
        `deploy/k8s/base/apps/caddy/Caddyfile`
     2) redeploy Caddy via GitOps
     3) enable strict enforcement with `STRICT_PROXY_AUTHN_BRANDING=1` once live checks are green.
     4) do not use `handle_path`; it strips `/authn` and breaks MFE asset paths.

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

## Related Documents

- `docs/branding/BRANDING_GUARDRAILS.md`
- `docs/branding/BRANDING_ROADMAP.md`
- `docs/branding/BRANDING_INCIDENT_TEMPLATE.md`
- `docs/BRANDING.md`
- `docs/operations/THEME_DEPLOYMENT.md`
- `docs/operations/OPENEDX_HOSTNAMES.md`
