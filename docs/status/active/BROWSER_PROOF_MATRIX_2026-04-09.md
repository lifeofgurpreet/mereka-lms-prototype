# Browser Proof Matrix

_Audience: Operators. Owner: Agent 1. Created: 2026-04-09. Status: active_

## Proof Levels

- **L0** = unreachable / DNS failure
- **L1** = redirect proof (HTTP 200/302 with non-empty response)
- **L2** = login-completion proof (auth flow completes, session established)
- **L3** = app-shell proof (React SPA loads, JS bundles present, title correct)
- **L4** = authenticated-app proof (logged-in user sees correct content via API)
- **L5** = business-flow proof (complete user journey: enroll, view, submit)

---

## Production

### Mereka (primary)

| Surface | Proof | Evidence |
|---------|-------|----------|
| LMS homepage | L1 | 200, 26KB |
| Studio | L1 | Redirects to Authentik OIDC |
| MFE authn/login | L3 | 2MB SPA, title="Authentication" |
| MFE learner-dashboard | L3 | 2MB SPA shell |
| MFE account | L3 | 2MB SPA, title="Account" |
| MFE profile | L3 | 2MB SPA, title="Learner Profile" |
| MFE discussions | L3 | 9KB shell |
| MFE gradebook | L3 | 3KB shell |
| MFE learning | L3 | 3KB shell |
| MFE authoring | L3 | 3KB shell |
| MFE config API | L3 | All URLs correct |
| **Login (lanea-platform-admin)** | **L4** | HTTP 200, session established, API returns user data |
| **Learner Home BFF** | **L4** | Returns courses, platformSettings, socialShareSettings |
| **Profile API** | **L4** | Returns username, email, is_active |
| auth-verify CronJob | PASS | 9/9 |
| cert-verify CronJob | PASS | 5/5 |

### Biji-Biji

| Surface | Proof | Evidence |
|---------|-------|----------|
| LMS homepage | L1 | 200, 26KB |
| MFE authn/login | L3 | 3.3KB SPA shell |
| MFE config API | L3 | **All URLs correct** (RCB-01 fixed) |
| **Login (lanea-bb-learner)** | **L4** | HTTP 200, session established, API returns user data |

### Skill Our Future

| Surface | Proof | Evidence |
|---------|-------|----------|
| LMS homepage | L1 | 200, 25KB |
| MFE apps (academyv2 domain) | L3 | 3.3KB SPA shell |
| MFE config API | L3 | **All URLs correct** (RCB-01 fixed) |

---

## Dev

| Surface | Tenant | Proof | Evidence |
|---------|--------|-------|----------|
| LMS homepage | Mereka | L1 | 200 |
| LMS homepage | Biji-Biji | L1 | 200, 25KB, title="Biji-Biji Academy" |
| LMS homepage | SOF | L1 | 200, 25KB |
| Studio | All 3 | L1 | 200, redirects to authn |
| MFE apps | All 3 | L3 | 302→authn/login, SPA shells load |
| MFE config API | All 3 | L3 | All URLs correct per tenant |
| Dev runtime proof | All | **40/40 PASS** | `verify-dev-runtime-proof.sh` |
| MFE config API verify | All | **24/24 PASS** | `verify-mfe-config-api.sh` |

---

## Staging

| Surface | Proof | Evidence |
|---------|-------|----------|
| LMS homepage | **L0** | Timeout — LMS CrashLoopBackOff (cluster CPU exhaustion) |
| MFE authn/login | L3 | 200 — MFE works because static assets don't need LMS |
| All LMS-dependent surfaces | **L0** | Blocked by cluster CPU exhaustion |

Staging pod health: 25 Running, 5 Unknown (8d stale), 4 Error, 2 CrashLoop.
Root cause: cluster CPU exhaustion (0/6 nodes available for scheduling).

---

## Remaining L5 proofs needed

1. Course enrollment + course view (any tenant)
2. Studio content authoring flow
3. Enterprise learner portal flow (blocked by `bff.has_read_access` — backlog)
4. Non-primary tenant login → dashboard → tenant-specific redirect
5. Profile page render for authenticated user (was blank — #1467)
