# TTFS: Time-to-First-Success Onboarding

Tracks the end-to-end learner onboarding funnel from initial registration through
completing the first lesson. Used to detect regressions in the onboarding path and
to set SLOs for learner activation.

---

## What TTFS Measures

**TTFS** is the wall-clock time between a new learner submitting the registration form
and recording their first courseware completion event (unit-level or problem submission).

It is a composite of four sequential steps:

| Step | Start | End |
|------|-------|-----|
| 1. Registration | Submit `/register` form | Account created, verification email sent |
| 2. Login | Submit `/authn/login` | Dashboard visible, session cookie set |
| 3. Course Enrollment | Click "Enroll" on course catalog | Enrollment record created in LMS |
| 4. First Lesson Completion | Open unit/problem | Completion event emitted (via Completion API or grade event) |

The SLO is expressed as a **p95 funnel time** — 95% of new learners should reach
First Lesson Completion within the target budget.

---

## The 4-Step Funnel

### Step 1 — Registration

- **URL**: `https://apps.academyv2.mereka.io/authn/register`
- **LMS fallback**: `https://academyv2.mereka.io/register`
- **Success signal**: HTTP 200 on POST to `/api/user/v1/account/`; email verification
  dispatched via Celery + SMTP relay
- **Failure modes**: SMTP relay down, MySQL write failure, CSRF mismatch, rate-limit
  triggered

### Step 2 — Login

- **URL**: `https://apps.academyv2.mereka.io/authn/login`
- **Success signal**: JWT cookie set; redirect to Dashboard
- **Failure modes**: Authentik OIDC session not established, cookie `SameSite` mismatch,
  Caddy upstream timeout

### Step 3 — Course Enrollment

- **API**: `POST /api/enrollment/v1/enrollment`
- **UI path**: Course discovery → course detail → "Enroll" button (MFE or LMS native)
- **Success signal**: `is_active: true` in enrollment response; event
  `org.openedx.learning.course.enrollment.changed.v1` emitted on Redis Streams
- **Failure modes**: Course not in Discovery catalog, enrollment rules blocked,
  payment gateway redirect triggered unexpectedly

### Step 4 — First Lesson Completion

- **Courseware URL**: `https://apps.academyv2.mereka.io/learning/course/<course_id>/`
- **Completion API**: `POST /api/completion/v1/completion-batch/` (block completions)
- **Success signal**: Completion record written, progress bar updates
- **Failure modes**: MFE JS error, courseware unit unavailable, Celery worker
  backpressure, MongoDB write latency spike

---

## Interpreting Results

### TTFS Funnel Metrics

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Registration → Login (p50) | < 2 min | 2–5 min | > 5 min |
| Login → Enrollment (p50) | < 1 min | 1–3 min | > 3 min |
| Enrollment → First Lesson (p50) | < 2 min | 2–5 min | > 5 min |
| Total TTFS (p95) | < 10 min | 10–20 min | > 20 min |

> Delays above "Warning" threshold should trigger a Loki log query to identify the
> slowest step. Delays above "Critical" require on-call response.

### Step Drop-off Rates

Track what percentage of users who begin registration reach each subsequent step.
A drop-off spike at any step indicates a UX or infrastructure regression.

| Funnel Step | Healthy Drop-off |
|-------------|-----------------|
| Registration → Login | < 5% |
| Login → Enrollment | < 10% |
| Enrollment → First Lesson | < 15% |

---

## SLOs

| SLO | Target | Measurement Window |
|-----|--------|--------------------|
| Registration endpoint p95 latency | < 3 s | Rolling 7 days |
| Login success rate | ≥ 99% | Rolling 7 days |
| Enrollment API success rate | ≥ 99.5% | Rolling 7 days |
| Total TTFS p95 | < 10 min | Rolling 30 days |

SLO breach → page on-call via Alertmanager → `#lms-alerts` Slack.

---

## Manual Testing Checklist

Run this checklist after any infrastructure change that touches auth, enrollment,
or courseware serving.

### Step 1: Registration

- [ ] Navigate to `https://apps.academyv2.mereka.io/authn/register`
- [ ] Fill in name, email (use `+test` alias), username, password
- [ ] Submit form — expect HTTP 200 and "Check your email" confirmation
- [ ] Confirm verification email arrives within 2 minutes
- [ ] Click verification link — expect redirect to Dashboard (not an error page)
- [ ] Verify account exists: `kubectl exec -n mereka-lms <lms-pod> -- python manage.py lms shell -c "from django.contrib.auth.models import User; print(User.objects.filter(email='...').exists())"`

### Step 2: Login

- [ ] Navigate to `https://apps.academyv2.mereka.io/authn/login`
- [ ] Enter credentials from Step 1
- [ ] Verify redirect to Dashboard at `https://apps.academyv2.mereka.io/dashboard`
- [ ] Verify session cookie `edx-jwt-cookie-*` or `sessionid` is set in browser DevTools
- [ ] Check no SSO redirect loop (max redirects = 3)

### Step 3: Course Enrollment

- [ ] From Dashboard, navigate to course catalog
- [ ] Select any published course with `enrollment_start` in the past
- [ ] Click "Enroll" button
- [ ] Verify redirect to courseware or confirmation page
- [ ] Confirm enrollment via API: `curl -H "Cookie: sessionid=..." https://academyv2.mereka.io/api/enrollment/v1/enrollment?course_id=<id>`
- [ ] Verify `is_active: true` in response

### Step 4: First Lesson Completion

- [ ] Navigate to enrolled course → first section → first unit
- [ ] Scroll through or submit a problem
- [ ] Verify progress bar updates (green tick on unit)
- [ ] Verify completion API call in browser Network tab (200 from `/api/completion/v1/completion-batch/`)
- [ ] Check event emitted: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms-worker --tail=50 | grep completion`

---

## Integration with Lighthouse Budgets

Each step in the TTFS funnel has a corresponding Lighthouse budget in
`infrastructure/monitoring/lighthouse-budgets.json`.

| Funnel Step | MFE Path | LCP Budget | INP Budget |
|-------------|----------|-----------|-----------|
| Registration | `/authn/register` | 2500 ms | 200 ms |
| Login | `/authn/login` | 2500 ms | 200 ms |
| Dashboard | `/dashboard` | 2500 ms | 200 ms |
| Courseware | `/learning/course` | 2500 ms | 200 ms |

Run Lighthouse CI against each path after a new MFE build:

```bash
lhci collect --url=https://apps.academyv2.mereka.io/authn/login
lhci collect --url=https://apps.academyv2.mereka.io/authn/register
lhci collect --url=https://apps.academyv2.mereka.io/dashboard
```

Performance regressions at any funnel step increase TTFS directly — slow LCP on the
registration page delays the learner's first interaction.

---

## Observability Hooks

- **Loki queries**: Filter `app=lms` for `POST /api/user/v1/account/` (registration),
  `POST /api/enrollment/v1/enrollment` (enrollment), `POST /api/completion/v1/completion-batch/`
- **Prometheus metric**: `openedx_enrollment_created_total` (if instrumented)
- **Redis Streams**: `org.openedx.learning.course.enrollment.changed.v1` consumer lag

---

## Related Documents

- `docs/operations/LIGHTHOUSE_BUDGETS.md` — Core Web Vitals budgets per MFE route
- `docs/operations/TROUBLESHOOTING.md` — Site-down diagnostic runbook
- `docs/ops/security/AUTH_AND_PERMISSIONS.md` — Auth flow details
- `scripts/qa/verify-ttfs-onboarding.sh` — Offline config verification
- `.github/workflows/ttfs-onboarding.yml` — CI workflow
