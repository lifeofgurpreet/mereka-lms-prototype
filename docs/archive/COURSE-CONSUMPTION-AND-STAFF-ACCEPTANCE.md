## Lane P3 — Post-Login Deep-Route Host Handoff Closure

### Current live failing URLs

- `https://apps.academyv2.mereka.dev/learning/course/course-v1:MEREKA+MEKA-2149245377+RUN-2149245377/home`
- `https://apps.academyv2.mereka.dev/course-authoring/home`

### Exact handoff trace

For both learner and Studio deep routes, the live trace is:

1. Browser starts on the correct apps-host MFE URL.
2. Authn login succeeds against LMS `POST /api/user/v2/account/login_session/`.
3. LMS returns `200` JSON with `redirect_url = https://academyv2.mereka.dev/dashboard`.
4. The authn MFE client then overrides that redirect when `next` is a deep route.
5. The override rebuilds the final URL as `LMS_BASE_URL + next`.
6. Browser lands on `https://academyv2.mereka.dev/...`.
7. LMS receives `GET /learning/...` or `GET /course-authoring/home` on the academy host and returns `404`.

### Exact host-handoff source

The wrong-host deep-route handoff is produced in the authn MFE client bundle, not by LMS login-session response generation and not by stale runtime MFE config.

Classification: `AUTHN_MFE_REDIRECT_BUG`

Live bundle proof:

- authn bundle contains:
  - `u=r&&!o.includes(r)?(0,s.zj)().LMS_BASE_URL+r:o`
- this logic rewrites deep-route `next` values to the LMS host instead of keeping them on the current apps host

### Exact fix

Repo-owned fix path:

- add a deterministic authn bundle patch script:
  - `infrastructure/tutor/patches/patch-authn-deep-route-handoff.py`
- wire it into the Tutor MFE build path after `npm run build`
- patch only known MFE deep-route prefixes so they use:
  - `window.location.origin + next`
- preserve LMS-host redirects for non-MFE paths

Guardrail:

- `scripts/qa/test-authn-deep-route-handoff-patch.sh`

### Live verification result

Not live yet from this lane.

Local proof completed:

- patch test passes
- CI static script list stays valid

Live learner course home and Studio home remain blocked until a new MFE image containing the authn patch is built, promoted, and re-proven.

### Lane status

Status: `CONDITIONALLY_CLOSED`

The source of the wrong-host handoff is now exact and the smallest repo-owned fix is authored. The remaining step is delivery:

1. merge the authn patch
2. build/publish the updated generic `mfe` image
3. promote that image to dev
4. re-prove:
   - learner course home on apps host
   - Studio home on apps host
