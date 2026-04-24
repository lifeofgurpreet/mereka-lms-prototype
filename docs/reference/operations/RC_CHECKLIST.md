---
title: Release Candidate Checklist
type: reference
owner: platform-release
status: active
---

# Release Candidate Checklist

The hard rubric for *"are we shippable right now?"* Runs against live envs,
not against intention. Every row is a command you can run or a URL you can
click. If any row fails, we are not RC-ready.

This is NOT a CI gate. It's the human checklist before declaring a release
candidate "proven" end-to-end. CI covers some of these rows automatically
(noted where); the rest are operator-driven because they require a real
browser, real Google SSO, or real visual verification.

## How to read this

- ✅ = automatable today (CI covers it)
- 🧑 = operator must click / look / log in
- 🔗 = depends on another row

| # | Lane | Check | Command / URL | Gate |
|---|---|---|---|---|
| 1 | **Build** | Latest push to main got a green Build Tutor Images run | `gh run list --workflow="Build Tutor Images" --limit 3` | ✅ |
| 2 | **Promotion** | An `automation/mereka-lms-dev-*` PR opened in bbi-infra for that SHA within 15 min | `gh pr list --repo Biji-Biji-Initiative/bbi-infrastructure --search 'automation/mereka-lms-dev'` | ✅ |
| 3 | **Argo sync** | Dev app is `sync=Synced` on the bbi-infra commit that came from the promotion PR | `kubectl --context rke2-nonprod -n argocd get application mereka-lms-dev -o jsonpath='sync={.status.sync.status} rev={.status.sync.revision}{"\n"}'` | ✅ |
| 4 | **Pod roll** | MFE + LMS deployment `image` fields match the digests from the promotion PR body | `kubectl --context rke2-nonprod -n mereka-lms-dev get deploy mfe lms -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'` | ✅ |
| 5 | **Bundle integrity** | Live HTTPS fetch of `/authn/login` serves the expected bundle hash | `curl -sL https://apps.academyv2.mereka.dev/authn/login | grep -oE 'app\.[a-f0-9]+\.js' | head -1` | ✅ |
| 6 | **Login — dev** | Click "Sign in with Mereka" on `apps.academyv2.mereka.dev/authn/login`, reach learner dashboard without a console error | browser | 🧑 |
| 7 | **Login — staging** | Same, on `staging.apps.academyv2.mereka.io` | browser | 🧑 |
| 8 | **Login — prod** | Same, on `apps.academyv2.mereka.io` | browser | 🧑 |
| 9 | **Admin access — LMS** | `/admin/` loads without 403 for a human in the 8-person baseline | browser after login | 🧑 |
| 10 | **Admin access — Studio** | `studio.academyv2.mereka.dev/signin` → LMS login → Studio landing, "New Course" button visible | browser | 🧑 |
| 11 | **Lesson page** | Enrolled learner can open `/learning/course/<course-id>/home` without error boundary | browser (enrolled canary) | 🧑 |
| 12 | **Courseware unit** | Lesson unit renders, no JS `ReferenceError`, video embeds resolve | browser DevTools console | 🧑 |
| 13 | **Progress page** | `/learning/course/<course-id>/progress` loads without 500 or blank state | browser | 🧑 |
| 14 | **Forum post** | Submit a thread via `/discussion` → 200 + visible in thread list | browser | 🧑 |
| 15 | **Logout + re-login** | After logout, session cookie cleared, re-login works without stale-cookie 403 | browser | 🧑 |
| 16 | **Mobile 390px** | Learner dashboard + lesson page + progress render without horizontal scroll at 390px | browser DevTools device mode | 🧑 |
| 17 | **CSP** | `/authn/login` console shows no `Content-Security-Policy` violations | browser DevTools | 🧑 |
| 18 | **Session cookie** | `Domain` attribute on session cookies matches `.mereka.io` for staging/prod, `.mereka.dev` for dev | browser DevTools Application tab | 🧑 |
| 19 | **Platform admin runtime backstop** | `MEREKA_PLATFORM_ADMIN_EMAILS` env var on LMS deployment contains the 8-person baseline | `kubectl --context $CTX -n $NS get deploy lms -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MEREKA_PLATFORM_ADMIN_EMAILS")].value}{"\n"}'` | ✅ (becomes auto once #1919 T3 ships) |
| 20 | **External uptime** | Upptime (status.mereka.dev) reports green for LMS/studio/apps prod URLs for the last 30 min | 🔗 OBS-004 | 🧑 then ✅ |
| 21 | **Synthetic login probe** | GitHub Actions `smoke-authn-mfe.yml` green for the last 2 scheduled runs | 🔗 OBS-003 | ✅ once OBS-003 lands |
| 22 | **Client-side Sentry** | Authn MFE bundle contains `@sentry/browser`; verify one test JS error in dev surfaces in Sentry within 2 min | 🔗 OBS-001 | 🧑 once OBS-001 lands |
| 23 | **Post-deploy E2E** | `Post-Deploy E2E Gate` workflow green on the current main | `gh run list --workflow="Post-Deploy E2E Gate" --limit 1` | ✅ |
| 24 | **Tracker health** | `br doctor` returns clean (no ERROR / no sqlite malformed) | `br doctor 2>&1 | grep -E '^(OK|WARN|ERROR)'` | ✅ |
| 25 | **Platform admin parity** | Live DB superusers across dev/staging/prod all match `bbi-infrastructure/identity/access/platform-access.yaml` | `bash bbi-infrastructure/identity/access/audit/admin-parity.sh` | ✅ |

## Scoring

- **Auto rows green (✅ gates)**: required for any release candidate — CI should be able to prove these without a human.
- **Operator rows green (🧑 gates)**: required for "proven RC" — requires a 15-minute human pass.
- **Pending-dependency rows (🔗)**: gated on OBS-001/003/004 landing; we should have these by end of next sprint.

## RC phases

1. `repo_complete` = rows 1–4, 19, 23, 24, 25 green (machine-provable)
2. `runtime_proven` = rows 5–18 green on dev at minimum
3. `operationally_closed` = rows 5–22 green on all 3 envs

Current (2026-04-20): `repo_complete` for the cleanup lane; `runtime_proven` for dev (rows 5, 6 unchecked by human but curl-level proven); `not yet operationally_closed` because rows 20–22 depend on OBS implementation that's still at bead-only stage.

## Related artifacts

- `docs/status/active/NEXT-SPRINT-QUEUE.md` — ordered next-sprint work to close remaining gates
- GitHub Issue #1919 — platform-access unified contract (drives row 19)
- PR #1917 — observability audit evidence (drives rows 20–22)
- PR #1923 — closed the E2E red gate (row 23)
