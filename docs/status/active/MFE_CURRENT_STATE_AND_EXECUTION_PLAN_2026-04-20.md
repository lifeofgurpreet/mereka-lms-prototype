# Mereka LMS MFE Current State and Execution Plan

Observed: 2026-04-20 local / 2026-04-19 UTC
Repo: `Biji-Biji-Initiative/mereka-lms`

## Live Truth

- `origin/main`: `a9eca5049` — `fix(qa): make verify-release-dry-run-contract.sh absence-tolerant (Wave 9 item 5, bead mereka-lms-2xwo) (#1892)`.
- Argo dev: Synced / Healthy at GitOps revision `e729e2599d6294bf28e6cec6018f7414890babc5`.
- Dev MFE deployment: `1/1`, image `ghcr.io/biji-biji-initiative/mereka-lms/mfe:e7bfe2e0a93aff77a9b8c8ce2c4fe1c7aaf921a5@sha256:6f6b78eb2675f35a2bb6435be823fade4314325b0e3fb276d1ae093494c5b4ab`.
- Open PR queue: only stale dirty PRs `#1808`, `#1791`, `#1768`; no active MFE PRs are open.
- CI on latest main: push workflows for `a9eca5049` still running/queued at observation time; do not assume green until rechecked.

## What Actually Changed Since The First Learning-MFE Proof

Recent main history matters because several plausible fixes were retracted:

- `#1870` captured the browser proof: Learning MFE has real lesson-page defects, not just doc/spec drift.
- `#1875` attempted to fix courseware/progress by adding `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"] = True`.
- `#1881`/`#1883` retracted that path: the flag is not read by Ulmo runtime outside tests, and the app-repo Django settings file is a shadow surface.
- `#1885`/`#1886` corrected the runtime settings model: live LMS settings come from bbi-infrastructure configmap overlays, not app-repo `deploy/k8s/base/apps/openedx/settings/lms/production.py`.
- `#1888` proved `LEARNING_MICROFRONTEND_URL` is not consumed by any built MFE; the relevant key is `LEARNING_BASE_URL`.
- `#1889` through `#1892` are Wave 9 script/QA absence-tolerance fixes for deleting app-repo shadow overlays. They improve the road, but they do not close the Learning MFE bugs.

## Current MFE Bug State

The following beads remain open and should be treated as the active MFE execution queue:

- `mereka-lms-m0u5.10.1` P0 — Learning MFE courseware/progress error boundaries block lesson access.
- `mereka-lms-m0u5.10.2` P1 — progress route falls back to legacy Django LMS on mobile.
- `mereka-lms-m0u5.10.3` P1 — course-end route times out and redirects to a unit on mobile.
- `mereka-lms-m0u5.10.4` P1 — unit view has 986px horizontal overflow at 390px viewport.
- `mereka-lms-m0u5.10.5` P1 — learner-dashboard cold-context load hits error boundary.
- `mereka-lms-m0u5.10.6` P2 — Learning header slot DOM probes cannot locate wrappers/mobile nav trigger.
- `mereka-lms-m0u5.10.7` P0 — testadmin credential exposure was handled by evidence/SSO work, but verify bead status before ignoring it.

The important point: the first code fix was a false positive. The next team must work from runtime proof, not grep plausibility.

## Architecture Rules For MFE Fixes

1. Do not edit app-repo shadow Django settings for runtime behavior. For live LMS Django settings, the authoritative source is bbi-infrastructure:
   `apps/mereka-lms/overlays/<env>/patches/production-<env>.py`.
2. For DB-backed Open edX toggles, use waffle flags or a seed/management-command path. Do not invent a `FEATURES[...]` setting unless runtime code reads it.
3. For MFE runtime config, verify the built bundle consumes the key before adding it. `LEARNING_MICROFRONTEND_URL` is not consumed; `LEARNING_BASE_URL` is.
4. For routing, `/learning/*` should remain MFE-owned. Caddy should proxy only API/auth subpaths such as `/learning/api/*`, `/learning/login_refresh`, `/learning/csrf/*`, `/learning/oauth2/*`, and `/learning/login`.
5. Do not delete or bulk-retire HINT slots. `m0u5.2` showed most HINT slots have planned intent and runtime wiring. Missing acceptance criteria are spec debt, not proof of dead code.

## Recommended Execution Sequence

### Batch A — Make Learning MFE Navigation Usable

Owner profile: senior Open edX / Django / MFE runtime agent.

1. Start with `m0u5.10.1`.
2. Reproduce D-03/D-04/D-05 using Playwright on dev.
3. Inspect runtime waffle flags in the live pod and upstream Ulmo routing helpers:
   `lms.djangoapps.courseware.toggles`, `CourseMicroFrontendFlag`, `courseware_mfe`, `learner_home_mfe`, `course_experience.use_new_courseware_container`.
4. Determine which flag/DB setting actually gates courseware and progress MFE behavior.
5. If a flag flip fixes it, implement a durable seed/management-command path and document rollback.
6. If no flag fixes it, produce evidence-only with exact upstream code path and next patch surface.

Batch A must not ship another settings-only guess.

### Batch B — Progress Route Contract

Owner profile: routing/browser-proof agent.

1. Work `m0u5.10.2`.
2. Compare desktop/tablet/mobile redirect chains for:
   `/learning/course/<course-id>/progress`.
3. Capture initial URL, final URL, response chain, console errors, and MFE config API payload.
4. Desired final state: final URL stays on `apps.../learning/course/<course-id>/progress`.
5. Do not fix by routing mobile users to Django. Django progress is legacy compatibility, not the target.
6. Add an authenticated deep-route smoke/assertion if the mechanism becomes clear.

Batch B should run after or alongside Batch A, but it must not hide Batch A failures with Caddy rewrites.

### Batch C — Course-End and Overflow

Owner profile: frontend/runtime CSS agent.

1. Work `m0u5.10.3` and `m0u5.10.4` together only after Batch A produces a usable unit/courseware path.
2. For course-end, prove whether redirect-to-unit is upstream intended behavior or local config defect.
3. For overflow, assert `document.body.scrollWidth <= viewportWidth` at 390px and identify the exact fixed-width element.
4. Prefer tenant SCSS fixes only when the DOM owner is clear. If the overflowing node is upstream structural layout, file upstream and carry a minimal scoped patch if needed.

### Batch D — Cold-Context Dashboard

Owner profile: auth/session/bootstrap agent.

1. Work `m0u5.10.5`.
2. Reproduce cold-context dashboard error in a clean browser context.
3. Compare fresh vs warmed cookies, CSRF, JWT refresh, `/api/mfe_config/v1`, and learner dashboard API calls.
4. Fix the earliest failing bootstrap/auth surface, not a cosmetic error boundary.

### Batch E — DOM Probe and Slot Observability

Owner profile: QA/verifier agent.

1. Work `m0u5.10.6`.
2. Treat missing `data-slot-id` as an upstream instrumentation limitation unless proven otherwise.
3. Do not infer "slot not rendered" from missing wrapper attributes.
4. Improve verifiers to use visual/semantic selectors for Learning MFE where upstream does not emit slot IDs.

## Active Reviewer Position

The highest-risk mistake now is repeating #1875: shipping a plausible, grep-derived fix that never reaches runtime. Every MFE fix PR should include:

- live runtime proof before patch,
- patch against the correct authority surface,
- live runtime proof after deploy, or an explicit "not deployed yet" note,
- browser proof at 390, 1024, and 1440 where the defect is viewport-dependent,
- a retraction note if the PR changes a prior claim.

## Prompt To Hand To The Implementor Team

You are taking over the Learning MFE repair lane for `Biji-Biji-Initiative/mereka-lms`.

Start by re-proving live truth:

```bash
cd "$MEREKA_LMS_REPO"   # repo checkout root for Biji-Biji-Initiative/mereka-lms
git fetch origin main --quiet
git log origin/main -8 --oneline
gh pr list --repo Biji-Biji-Initiative/mereka-lms --state open --limit 30
kubectl --context rke2-nonprod -n argocd get application mereka-lms-dev -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}'
kubectl --context rke2-nonprod -n mereka-lms-dev get deploy mfe -o jsonpath='ready={.status.readyReplicas}/{.status.replicas} image={.spec.template.spec.containers[0].image}'
```

Read these files before changing anything:

```bash
git show origin/main:docs/ops/evidence/m0u5.1-learning-mfe-browser-proof-2026-04-19.md
git show origin/main:docs/ops/evidence/m0u5.10.1-retraction-noop-flag-2026-04-19.md
git show origin/main:docs/ops/evidence/vfd5-mfe-consumption-proof-2026-04-19.md
git show origin/main:docs/ops/evidence/shadow-settings-source-identified-2026-04-19.md
git show origin/main:docs/ops/evidence/m0u5.2-mfe-hint-slot-decision-matrix-2026-04-19.md
git show origin/main:docs/reference/architecture/MFE_ROUTE_TO_DIST_CONTRACT.md
```

Primary work:

1. Fix or root-cause `mereka-lms-m0u5.10.1` first. Do not use `ENABLE_COURSEWARE_MICROFRONTEND`; it was retracted as a no-op.
2. Investigate the actual Ulmo courseware/progress gates: waffle flags, `CourseMicroFrontendFlag`, route helpers, and live DB state.
3. If runtime settings are needed, patch bbi-infrastructure overlays, not app-repo shadow settings.
4. Then work `mereka-lms-m0u5.10.2` progress mobile fallback. Keep `/learning/course/<course-id>/progress` MFE-owned; do not "fix" it by intentionally falling back to Django.
5. Only after the core courseware/progress route is functional should you address overflow (`m0u5.10.4`) and course-end (`m0u5.10.3`).

Hard rules:

- Do not bulk-delete HINT slots.
- Do not rely on static grep alone.
- Do not call a PR successful until runtime pod state or browser proof confirms the mechanism.
- Use one small PR per defect or tightly coupled defect group.
- Update Beads and run `br sync --flush-only` after tracker changes.
- Run docs catalog and docs authority checks after docs changes:
  `python3 tools/docs/verify/build-doc-catalog.py`
  `bash scripts/qa/verify-docs-authority-invariants.sh`

Done for this slice means either:

- a real fix PR is opened with runtime-proof evidence and rollback notes, or
- an evidence-only PR closes a false hypothesis and points to the next exact patch surface.
