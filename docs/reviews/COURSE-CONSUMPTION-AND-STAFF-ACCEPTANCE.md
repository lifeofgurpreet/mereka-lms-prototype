# Course Consumption And Staff Acceptance

Date: 2026-03-13  
Lane: P2  
Environment: `mereka-lms-dev`

## Verdict

Status: `OPEN`

The first repo-owned blocker was fixed in `mereka-lms` PR `#897`, and that generic `mfe`
fix is now live in dev. The next first blocker is a new repo-owned login redirect defect:
successful authn MFE login returns the learner deep-route redirect on the LMS host
(`academyv2.mereka.dev`) instead of the apps MFE host (`apps.academyv2.mereka.dev`).

## What Was Freshly Runtime-Proven

### Learner authentication

- Synthetic learner `lanea-enterprise-learner` can sign in successfully through the authn MFE.
- Final authenticated route after sign-in: `https://academyv2.mereka.dev/dashboard`

### Admin user-management surface

- Synthetic platform admin `lanea-platform-admin` can sign in and open the live Django admin user-management surface.
- Final route: `https://academyv2.mereka.dev/admin/auth/user/`
- This proves real admin-side management capability at the live changelist/data-loading layer.

## What Was Only Route-Level Before And Is Now Runtime-Proven As Broken

### Learner course consumption

Fresh browser proof against:

- learner: `lanea-enterprise-learner`
- course: `course-v1:MEREKA+MEKA-2149245377+RUN-2149245377`
- route: `https://apps.academyv2.mereka.dev/learning/course/course-v1:MEREKA+MEKA-2149245377+RUN-2149245377/home`

Observed result:

- the route resolves
- the learning MFE loads its bundles
- the page terminates in the global error boundary:
  - `An unexpected error occurred. Please click the button below to refresh the page.`

This is not a missing-route problem. It is a live frontend render failure after bundle load.

## First Failed Request / Error

First recurring failing requests captured in-browser:

- `401 https://apps.academyv2.mereka.dev/login_refresh`

These were present, but they were not the primary render blocker.

First decisive JS error captured in-browser:

```text
TypeError: Cannot convert undefined or null to object
    at Object.keys (<anonymous>)
    at .../learning/76.308849641acf3aa90f09.js
    at ... organizePlugins ...
```

Source-map reconstruction showed the live learning bundle is using
`@openedx/frontend-plugin-framework/src/plugins/data/utils.jsx`, where
`organizePlugins()` validates slot operations against supported plugin operations.

The shipped frontend-plugin-framework constants in the live learning bundle support only:

- `insert`
- `hide`
- `modify`
- `wrap`

They do **not** support `replace`.

## Exact Repo-Owned Blocker

`infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` was still registering active slot
overrides using an unsupported `PLUGIN_OPERATIONS.Replace` pattern for:

- `org.openedx.frontend.layout.header_logo.v1`
- `org.openedx.frontend.learner_dashboard.no_courses_view.v1`
- `org.openedx.frontend.layout.header_learning_help.v1`

That mismatch is consistent with the live learner course failure and with the broken/stale
dashboard rendering observed after successful sign-in.

Owner: `mereka-lms`

## Durable Fix Prepared

A narrow repo fix was prepared to convert those unsupported replacement slots into the
supported `Hide + Insert` pattern, plus a new compatibility test so this cannot silently
re-enter the repo.

Prepared repo changes:

- `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`
- `scripts/qa/test-mfe-slot-operation-compat.sh`
- `scripts/qa/verify-mfe-header-branding.sh`
- `.github/ci-scripts-static.txt`

Repo PR:

- `#897`

## Local Repo Verification For The Fix

Passed locally on the fix branch:

- `bash scripts/qa/test-mfe-slot-operation-compat.sh`
- `bash scripts/qa/verify-mfe-header-branding.sh`
- `bash scripts/qa/verify-mfe-plugin-slots.sh`
- `bash scripts/qa/verify-ci-script-list.sh`
- `bash scripts/qa/verify-new-ci-static-entries.sh --staged-only`

## Post-#897 Live Convergence Check

`#897` merged on `2026-03-13` as commit `6233c55b0c51ed5846d6b4b4c4746d9a80c857b3`.

Live dev **has** now picked up that fix.

Fresh runtime proof shows the currently deployed generic apps MFE is now:

- deployment: `mfe`
- live image: `ghcr.io/biji-biji-initiative/mereka-lms/mfe:6233c55b0c51ed5846d6b4b4c4746d9a80c857b3`

Direct inspection of the live learning and authoring bundles no longer shows the old
unsupported slot semantics. The `Replace`-style slot operations isolated earlier are gone
from the live generic `mfe` payload.

That means the original first blocker is cleared, and the next first blocker is now the
post-auth redirect contract between LMS login_session and the apps MFE routes.

## New First Blocker After Rollout

Fresh browser proof now shows:

- learner sign-in succeeds through authn MFE
- LMS `POST /api/user/v2/account/login_session/` returns HTTP `200`
- session + JWT cookies are set correctly
- final browser location is still wrong:

```text
https://academyv2.mereka.dev/learning/course/course-v1:MEREKA+MEKA-2149245377+RUN-2149245377/home
```

Observed page result:

```text
Page Not Found | Mereka Academy Dev
```

This is no longer a bundle-crash problem. It is now a redirect-host normalization problem.

First decisive live proof:

- `login_session` succeeds on LMS origin
- `redirect_url` resolves to an MFE-owned deep route (`/learning/...`)
- but it is returned on the LMS host instead of the tenant apps host

The route/config contract already says MFE-owned deep routes belong on:

- `https://apps.academyv2.mereka.dev/learning`
- `https://apps.academyv2.mereka.dev/course-authoring`

So the current mismatch is:

- repo intent for MFE deep-route host: correct
- live login-session redirect host: wrong

## Exact Repo-Owned Follow-Up Fix

The smallest repo-owned fix is to extend the existing tenant-aware login redirect middleware
in `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` so it also rewrites
successful `login_session` JSON `redirect_url` values when they point at known MFE deep
routes on the LMS host.

That fix is intentionally narrow:

- rewrite only known MFE path families such as `/learning` and `/authoring`
- preserve LMS-owned redirects such as `/enterprise/...`
- leave auth/session behavior unchanged

It also adds focused unit coverage for successful `login_session` JSON redirect rewriting.

`#898` merged on `2026-03-13` as commit `d24010e06eab59e1e8c1e90697fa8d0507c2472a`.

## Exact Post-Merge Publish Blocker

The redirect fix is now merged in `mereka-lms`, but the current first blocker is no longer
live route behavior inside the app. It is image-build trigger coverage.

Fresh post-merge proof:

- live LMS deployment is still:
  - `ghcr.io/biji-biji-initiative/mereka-lms/openedx:3b79796f6aac0d5a2bb44fb4639ef2f8ec57b9d7`
- the expected merged image tag does not exist yet:
  - `ghcr.io/biji-biji-initiative/mereka-lms/openedx:d24010e06eab59e1e8c1e90697fa8d0507c2472a`
- direct registry check returns:

```text
manifest unknown
```

The exact reason is now identified:

- `.github/workflows/build-tutor-images.yml` only triggers on:
  - `infrastructure/tutor/**`
  - `assets/branding/**`
  - the workflow file itself
- the merged redirect fix lives under:
  - `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py`
- so `#898` did not trigger an `openedx` image build at all

This is a repo-owned publish gap, not a new runtime mystery.

## What Remains Blocked

Still not freshly completion-proven in live dev:

- learner course player load beyond error boundary
- video playback
- XBlock / quiz interaction
- certificate visibility / download
- Studio authoring save/edit
- gradebook
- ORA grading

These remain blocked until the merged login-session redirect fix is actually built into a
new `openedx` image, promoted to dev, and re-proven live.

## Next Required Step

1. Merge the narrow build-trigger fix so `deploy/k8s/base/apps/openedx/**` changes publish
   a new `openedx` image.
2. Confirm `openedx:d24010e...` (or successor) is published.
3. Promote/deploy that image to dev.
4. Re-run learner course consumption proof on the same live course.
5. Re-run Studio authoring.
6. Only after those render-path blockers clear, continue into video, XBlock, gradebook,
   ORA, and certificate completion proof.
