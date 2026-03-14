# Course / Studio Auth Runtime Seam Closure

Date: 2026-03-14
Lane: P3f
Environment: `mereka-lms-dev`

## Start Snapshot

- UTC: `2026-03-14T08:03:29Z`
- `origin/main`: `fd188aa0`
- live `openedx`: `ghcr.io/biji-biji-initiative/mereka-lms/openedx:8a7f247641c5f8fb3e2600d73046670233d246b1`
- live `mfe`: `ghcr.io/biji-biji-initiative/mereka-lms/mfe:8a7f247641c5f8fb3e2600d73046670233d246b1`
- live pods:
  - `lms-7b486fcd94-r79lp`
  - `cms-75b86999fb-h7m76`
  - `mfe-5c57cdb74c-295d4`

## login_refresh Finding

`/login_refresh` is incidental, not causal. The browser-side `401` is bootstrap noise from
an unauthenticated call. With a real LMS session, `POST https://apps.academyv2.mereka.dev/login_refresh`
returns `200` and sets JWT cookies.

## Learner Course-Home Result — STILL_BROKEN

### Exact First Blocker (before correction)

The `/api/course_home/outline/` API returned `403 {"detail":"Course has not started"}` because:

| Source | `start` |
|--------|---------|
| CourseOverview (MySQL) | `2025-01-01` |
| Modulestore (MongoDB, authoritative) | `2030-01-01` |

### Safe Live Correction Applied

For the single target course `course-v1:MEREKA+MEKA-2149245377+RUN-2149245377`, the authoritative
modulestore start date was corrected to `2025-01-01`.

After correction:

- `GET /api/course_home/outline/... -> 200`

### New Downstream Blocker

- `GET /api/course_home/course_metadata/... -> 500`
- exact failing dependency:
  - `/consent/api/v1/data_sharing_consent?...&enterprise_customer_uuid=7ad11569-d027-4e9d-a08f-e65c57e27c8b`
- exact effect:
  - course metadata view raises `requests.exceptions.HTTPError`

Conclusion:

- the old learner blocker was the authoritative modulestore start date
- that blocker is cleared for this one course
- the new learner blocker is enterprise consent / course-metadata runtime failure

Learner status: **STILL_BROKEN**

## Studio Result — STILL_BROKEN

### Browser-Proven First Failure

The first Studio blocker is a parse-time JavaScript failure in the authn MFE bundle.

- final URL remains on apps-host authn:
  - `https://apps.academyv2.mereka.dev/authn/login?next=https%3A%2F%2Fapps.academyv2.mereka.dev%2Fcourse-authoring%2Fhome`
- DOM remains only:
  - `<div id="root"></div>`
- first browser exception:
  - `SyntaxError: Unexpected token '^'`
- exact failing asset:
  - `https://apps.academyv2.mereka.dev/authn/app.da93d51e1fc72541fed6.js`
- exact location:
  - line `0`, column `620149`

### Exact Cause

The authn deep-route patch emitted an invalid regex prefix into the production bundle:

- broken emitted code:
  - `(^\/(?:authn|account|course-authoring|...`
- correct form:
  - `/^\/(?:authn|account|course-authoring|...`

Because this is a syntax error, the authn bundle never finishes parsing, React never mounts,
and the login form never renders. This reproduces on:

- `/authn/login`
- `/authn/login?next=.../course-authoring/home`
- `/authn/login?next=.../account/`

So the blocker is global authn-shell hydration failure, not Studio route ownership.

### Repo Fix Status

A tiny repo-owned fix exists:

- patch file:
  - `infrastructure/tutor/patches/patch-authn-deep-route-handoff.py`
- verification:
  - `scripts/qa/test-authn-deep-route-handoff-patch.sh`

The fix corrects the emitted regex delimiter so the patched authn bundle stays syntactically valid.

Studio status: **STILL_BROKEN**

## Safe Live Corrections Performed

| Action | Target | Safe | Scope |
|--------|--------|------|-------|
| Update modulestore `start = 2025-01-01` | 1 course | Yes | Single course |

## Exact Next Actions

| Gate | Status | Next Action | Owner |
|------|--------|-------------|-------|
| Learner course-home | **STILL_BROKEN** | Fix `/consent/api/v1/data_sharing_consent` 500 for this learner/course enterprise path | Runtime/app |
| Studio authn shell | **STILL_BROKEN** | Merge and deploy the authn parse-fix patch, then re-test `/authn/login` and `/course-authoring/home` | Repo/runtime |

## Lane Verdict

Status: `OPEN`

Learner moved past the old start-date authorization seam but is now blocked by a new
course-metadata consent failure. Studio now has an exact browser-proven root cause:
the authn bundle throws `SyntaxError: Unexpected token '^'` before hydration.
