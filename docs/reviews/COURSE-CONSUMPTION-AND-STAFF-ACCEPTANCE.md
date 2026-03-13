# Course Consumption And Staff Acceptance

Date: 2026-03-13  
Lane: P2  
Environment: `mereka-lms-dev`

## Verdict

Status: `OPEN`

The biggest remaining runtime blocker is no longer "route exists but unproven". It is a
live learner course-render failure with a repo-owned root cause in Tutor MFE slot wiring.

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

## Local Repo Verification For The Fix

Passed locally on the fix branch:

- `bash scripts/qa/test-mfe-slot-operation-compat.sh`
- `bash scripts/qa/verify-mfe-header-branding.sh`
- `bash scripts/qa/verify-mfe-plugin-slots.sh`
- `bash scripts/qa/verify-ci-script-list.sh`
- `bash scripts/qa/verify-new-ci-static-entries.sh --staged-only`

## What Remains Blocked

Still not freshly completion-proven in live dev:

- learner course player load beyond error boundary
- video playback
- XBlock / quiz interaction
- certificate visibility / download
- Studio authoring save/edit
- gradebook
- ORA grading

These remain blocked behind the first repo-owned frontend render failure until the
`Hide + Insert` slot-operation fix is merged, deployed, and re-proven live.

## Next Required Step

1. Merge and deploy the Tutor plugin slot-operation compatibility fix from `mereka-lms`.
2. Re-run learner course consumption proof on the same live course.
3. Only after course render clears, continue into video, XBlock, gradebook, ORA, and
   Studio authoring completion proof.
