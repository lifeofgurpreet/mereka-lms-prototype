# Branding Guardrails (Source Of Truth)
_Audience: Platform Eng + Product Eng • Last updated: 2026-02-07_

This doc exists to make branding changes predictable and low-drama.

Canonical execution model:
- `docs/branding/BRANDING_OPERATING_MODEL.md`
- `./scripts/branding/run-branding-gates.sh prod`
- CI/runtime enforcement:
  - `.github/workflows/ci.yml` (`branding-preflight`)
  - `.github/workflows/public-health-check.yml` (strict prod parity + artifact logs)

## The 3 Sources Of Truth

1. Canonical design-system tokens:
   - `assets/branding/tokens.css` (vendored from `bbbi-mereka-brand-assets`)
2. Runtime legacy theme delivery (LMS/Studio):
   - `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`
   - This is what the HTML loads via `*/templates/head-extra.html`
3. Runtime MFE delivery (Paragon):
   - `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
   - Requires rebuilding the MFE image to go live

## What We Verify (Before Deploy)

Run from repo root:

```bash
# Strictest, preferred gate
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
```

What this enforces:
- Logos/favicons/fonts exist and are wired correctly
- The runtime override CSS carries deep branded selectors (course cards, courseware, Studio wrapper)
- The MFE theme carries explicit selectors for authn/account/learner-dashboard/discussions surfaces
- Studio authoring selectors are enforced explicitly (`action-create-course`, `action-create-library`,
  `outline-complex`, `add-xblock-component`) via `scripts/qa/verify-studio-authoring-branding.sh`
- Branding revision markers exist (`--mereka-branding-rev`, `--mereka-mfe-branding-rev`) for deploy parity checks
- Token drift + provenance lock is caught (`assets/branding/tokens.css` + `assets/branding/tokens.provenance.json`)
- Footer logo sizing guardrails are present in runtime CSS (prevents oversized footer branding regressions)

## What We Verify (After Deploy, Live)

```bash
./scripts/branding/run-branding-gates.sh prod
# Includes source-time MFE prerequisite enforcement:
#   ./scripts/qa/verify-mfe-build-prereqs.sh
```

Notes:
- `verify-public-branding.sh` checks the main domain plus the client microsites (`academy.biji-biji.com`,
  `skillourfuture.academy.mereka.io`), and also validates Studio themed CSS wiring,
  MFE auth branding CTA text, Credentials health/admin reachability, Credentials API-root routing
  (`/` can be API-first redirect to `/health/`), Ecommerce root landing/dashboard auth shell,
  and Forum heartbeat/root landing.
- To enforce exact live-vs-source MFE branding revision parity, run:
  `STRICT_MFE_BRANDING_REV=1 ./scripts/branding/run-branding-gates.sh prod`
- If `BRANDING_LEVEL=deep` fails live but passes locally, production is running an older `openedx` image.

## Surface Audit (Gap-Finder)

This is intentionally non-fatal by default and answers: "which surface is still default?"

```bash
./scripts/qa/audit-branding-surfaces.sh prod
./scripts/qa/audit-branding-surfaces.sh prod --strict
```

Current audit coverage:
- LMS + microsite runtime override CSS depth
- Studio compiled CSS token/font wiring (primary + biji studio host)
- MFE authn shell + `mfe_config` brand fields
- MFE authn parity for primary + `apps.academy.biji-biji.com`
- Service-domain authn proxy surfaces (`ecommerce.* /dashboard`, `credentials.* /admin/login`)
- Service-domain root branding contract (`ecommerce.* /`, `forum.* /`, credentials API-first root)
- Branding revision marker parity (live vs source) for LMS/microsites
- Credentials root/admin/health availability
- Forum heartbeat + branded root landing

Visual regression coverage (manual/agent-run):
```bash
./scripts/qa/capture-branding-screenshots.sh prod
./scripts/qa/visual-regression-branding.sh prod --threshold 0.06
```
- Uses baseline-vs-candidate screenshot RMSE checks.
- Diff artifacts are written to `var/screenshots-diff/`.
- Add `--allow-bootstrap` for first-run baseline seeding.
- Add `--strict` when you need exact screenshot file-set parity.
- To enforce service-domain authn branding markers (`/authn/*`) as release-blocking:
  `STRICT_PROXY_AUTHN_BRANDING=1 ./scripts/branding/run-branding-gates.sh prod`

Canonical one-shot gate with screenshots + visual regression:
```bash
RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 VISUAL_ALLOW_BOOTSTRAP=1 \
./scripts/branding/run-branding-gates.sh prod
```

Scheduled VPS guardrail:
```bash
./scripts/infra/setup-vps-branding-visual-regression-cron.sh
```
This installs a periodic run (`scripts/infra/cron-branding-visual-regression.sh`) that captures screenshots
and runs RMSE diffs for both `prod` and `dev` by default.
By default it excludes dynamic/authenticated surfaces (dashboards/account/webhooks/forum/notes) to reduce noise;
override with `VISUAL_EXCLUDE_REGEX` in `var/branding-visual-regression.env` if needed.

## Most Common Failure Modes

1. Deep branding looks absent on production
   - Cause: cluster is still running an older `openedx` image and hasn’t picked up the new override CSS.
   - Fix: rebuild + deploy `openedx` image and rerun `BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod`.

2. MFE pages look unbranded even when LMS is perfect
   - Cause: MFE styling is baked into the MFE image; CSS changes in `mfe/mereka.scss` don’t apply until rebuild.
   - Fix: rebuild + deploy the MFE image.
   - Required contract gate: `scripts/qa/verify-mfe-image-branding.sh <image_ref>` validates
     the authn CSS bundle(s) referenced by `index.html` are branded before push/deploy.

2b. Health checks pass locally but fail live on revision marker checks
   - Cause: production is still serving an older image than current repo source.
   - Fix: deploy latest openedx/mfe images and bump GitOps pinned ref; rerun:
     `BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod`.

2c. Tutor template drift removes authn theme copy lines
   - Cause: generated MFE Dockerfile can omit theme asset copy in `authn-common`.
   - Fix: rerun `./infrastructure/tutor/apply-patches.sh`; it enforces:
     - `COPY indigo/env.config.jsx /openedx/app/`
     - `COPY indigo/mereka /openedx/app/mereka`

2d. Full MFE build fails with `Can't resolve '@openedx/frontend-plugin-framework'`
   - Cause: Tutor-generated MFE Dockerfile has Indigo `env.config.jsx` (which imports plugin framework),
     but missing plugin dependency install in one or more `*-common` stages.
   - Fix: rerun `./infrastructure/tutor/apply-patches.sh`; it now injects
     `npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'`
     idempotently across MFE common stages.
   - Verify by rebuilding and running:
     `./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest`
   - Preflight this before long builds:
     `./scripts/qa/verify-mfe-build-prereqs.sh`

2e. Token updates happen without upstream provenance
   - Cause: `tokens.css` edited directly with no pinned source commit/hash.
   - Fix: update provenance lock with `./scripts/branding/update-token-provenance.sh`
     and verify with `./scripts/branding/verify-token-drift.sh`.

3. “Worked right after deploy, broken later”
   - Cause: cached HTML references old hashed assets, or a partial rollout.
   - Fix: rerun `verify-public-branding.sh` (it busts cache on homepage fetch). If real users are impacted,
     purge CDN cache for `/` and retry.

4. Branding check scripts fail with shell errors instead of explicit gaps
   - Cause: unsafe shell interpolation in check scripts.
   - Fix: keep human-readable strings plain (no command-substitution quoting) and return
     explicit `host unreachable`/`could not fetch css` outcomes.

4b. False negatives on minified CSS checks under `set -o pipefail`
   - Cause: `printf ... | grep -q` can return non-zero on SIGPIPE after early grep match.
   - Fix: prefer here-strings (`grep ... <<<"$css"` / `rg ... <<<"$html"`) for deterministic checks.

5. Common and LMS runtime override CSS drift
   - Cause: edits made in one copy of `mereka-overrides.css` only.
   - Fix: always run `./scripts/branding/sync-brand-assets.sh` after CSS edits; it now syncs common -> LMS override CSS.

6. Credentials root behavior looks different than LMS/Studio
   - Cause: credentials service is API-first in production; `/` may redirect to `/health/`.
   - Fix: keep Caddy credentials routing intact and verify
     `./scripts/qa/verify-public-branding.sh prod` passes both admin + health checks.

7. Studio check false negatives after valid deploy
   - Cause: expecting a separate Studio runtime override CSS link in HTML, while the deployed contract
     is the themed `studio-main-v1` bundle selectors + no Google fonts.
   - Fix: treat `scripts/qa/verify-studio-authoring-branding.sh` as canonical for Studio authoring UI,
   and keep public gate checks aligned to that contract.

8. Screenshot captures exist but no measurable drift signal
   - Cause: captures are not compared against a baseline.
   - Fix: run `scripts/qa/visual-regression-branding.sh` and treat threshold failures as release blockers.

9. Service-domain authn pages render but `/authn/*` assets fail
   - Cause: `ecommerce.*` / `credentials.*` pages use authn shell paths, but Caddy is not proxying `/authn/*`
   for those hosts to `mfe:8002`.
  - Fix: add `handle /authn/* { import proxy "mfe:8002" }` in those host blocks and redeploy Caddy.
  - Important: do not use `handle_path` here; stripping `/authn` breaks MFE asset paths.

10. Ecommerce/forum roots look unbranded after deploy
   - Cause: root landing response contract drift in Caddy service host blocks.
   - Fix: keep branded root responses in `deploy/k8s/base/apps/caddy/Caddyfile`:
     - `Mereka Ecommerce Service` (`ecommerce.* /`)
     - `Mereka Forum Service` (`forum.* /`)
   - Verify:
     - `./scripts/qa/verify-public-branding.sh prod`
     - `./scripts/qa/audit-branding-surfaces.sh prod --strict`

## Deployment Reference

Use `docs/operations/THEME_DEPLOYMENT.md` as the canonical deployment runbook.

## Roadmap

The current bead-backed plan lives at:
- `docs/branding/BRANDING_ROADMAP.md`
