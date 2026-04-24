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

---

## Update 2026-04-11 — Agent 1 VNext real browser re-prove (dev mereka)

**Method:** agent-browser CLI (headless Chromium, snapshot-and-refs), `testadmin` credentials,
stable LMS pod `lms-79bfb484f8-pmmkv`, session cookies verified.

**Important correction:** The 2026-04-09 rows above show L3 for most MFE surfaces based on
HTTP 200 + title tag + JS bundle presence. Per `feedback-http200-ban.md` that is NOT valid
L3 proof. Real L3 requires a snapshot showing visible content; real L4 requires authenticated
data visibly rendered.

### Dev Mereka — honest browser matrix (screenshots saved to /tmp/dev-*.png)

| Surface | Honest Level | Evidence |
|---------|--------------|----------|
| LMS homepage `/` | **L3 PROVEN** | 28+ "View Course" links rendered, search box, sign-in link, cookie banner |
| `/authn/login?next=%2F` | **L3 PROVEN** | Full branded "Start learning with Mereka Academy" panel, Register/Sign in tabs, Username/Password fields, Sign in button, Forgot password link, Sign in with Mereka SSO button (screenshot confirmed) |
| Login flow (`testadmin`) | **L4 PROVEN** | Form submit → redirects to `apps.academyv2.mereka.dev/learner-dashboard/`, `Account menu for testadmin` visible |
| `/learner-dashboard/` | **L4 PROVEN** | Branded "Mereka Academy IN SESSION" header, Courses/Dashboard/Course Catalog nav, "MEREKA UPDATE" banner, "My Courses" heading, "Your Mereka Academy dashboard is ready" card, Learning Cockpit sidebar |
| `/account/` | **L4 PROVEN** | "Account Settings" heading, 7 sidebar sections (Account Info, Profile Info, Social Media, Notifications, Site Preferences, Linked Accounts, Delete Account), Mereka footer with social links |
| `/u/testadmin` (Profile) | **🔴 BROKEN** | Completely blank page. Title set to "Learner Profile" but DOM empty. Shared TypeError with other blank MFEs. Separate bug from missing MFE_CONFIG keys (see below). |
| `/learner-record/` | **L1 PROVEN** | Current dev image serves the route and authenticated redirect proof exists. This surface is no longer a packaging/Node 18 issue; visual/browser depth beyond L1 still needs fresh proof. |
| `/discussions/` | **🔴 BROKEN** | "Unexpected error occurred. Try again" error boundary. `TypeError: Cannot read properties of undefined (reading 'path')` in console. |
| `/communications/` | **🔴 BROKEN** | Blank page, no visible content. |
| `/learning/` | ⚠️ Partial | MFE shell renders "Mereka Academy learning flow — FOCUS MODE", footer. Body shows "Page not found" — expected: no course context. Needs course-open test for real L3+. |
| `/gradebook/` | ⚠️ Partial | Header + full Mereka footer render. No body content. Expected: needs course context. |
| `/authoring/` | 🔴 BROKEN | "Unexpected Application Error! 404 Not Found" — Authoring MFE router crash, likely needs course path. |

### Root cause 1: Missing MFE_CONFIG keys (source fix in PR #1536)

Console warnings across all broken MFEs:
```
App configuration error: SUPPORT_EMAIL is required by Studio Footer Help Content
App configuration error: TERMS_OF_SERVICE_URL is required by Studio Footer
App configuration error: PRIVACY_POLICY_URL is required by Studio Footer
App configuration error: ENABLE_ACCESSIBILITY_PAGE is required by Studio Footer
App configuration error: ORDER_HISTORY_URL is required by Header
```

All 6 tenant MFE hosts (dev/prod × mereka/biji-biji/SOF) missing all 5 keys.

**Source root cause:** `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` populates FAVICON/LOGO
MFE_CONFIG entries but never set footer/header text/link keys.

**Durable fix:** PR #1536 adds the 5 keys to MFE_CONFIG. Mirrors existing Django footer fallbacks
from `themes/mereka/lms/templates/footer.html`.

**Live patch (dev only):** SiteConfiguration.values["MFE_CONFIG"] patched on 6 rows (3 tenants ×
LMS host + apps host). MFE config API verified returning all 5 keys post-patch via curl.

**CRITICAL: Live patch is NOT sufficient to render Profile** — this implies Profile has a
secondary bug independent of missing config keys. See root cause 2.

### Root cause 2: Shared `TypeError: Cannot read properties of undefined (reading 'path')`

**Affected:** Profile, Learner-Record (though 404'd), Discussions, Communications

**Symptom:** TypeError fires during MFE shell bootstrap before React can mount anything. DOM
stays empty or shows react-error-boundary fallback. Config API returns valid data (verified).
JS bundles load HTTP 200 (verified).

**Unknown:** Which specific property access throws. Likely candidates:
- PARAGON_THEME init script (inline in HTML) accesses `location.hostname` variant map
- frontend-platform shell router init
- MFE common hooks reading from config object

**Blocker:** Cannot read the minified JS bundle to identify the call site without sourcemaps.
Next step: enable Sentry in dev to capture the full stack trace, or fetch a sourcemap build.

### Root cause 3: learner-record packaging gap (historical, now resolved on dev)

**Current source/runtime evidence:** the tracked MFE Dockerfile builds `learner-record`,
the MFE Caddyfile now has a `/learner-record` route, and later 2026-04-11 browser/runtime
proof in this same document records the route as present in the current dev image.

**Interpretation:** the older "not packaged / Node 18 build chain broken" diagnosis is stale.
The remaining work is to re-prove visual/runtime depth across environments, not to describe
`learner-record` as absent from the build anymore.

**Impact:** current dev proof only reaches L1 authenticated-route confirmation. Deeper
browser proof still needs to be refreshed where learner-record behavior matters.

### Confirmed working on dev (L4 proven, real browser)

- Landing page L3
- authn login page L3
- Login flow → learner-dashboard L4
- Account Settings L4
- No cross-tenant contamination (each tenant served from correct Site row)

### Confirmed broken on dev (real browser)

- Profile (blank, shared TypeError)
- Discussions (error boundary, shared TypeError)
- Communications (blank, shared TypeError)
- Authoring (404 / router crash without course context)

### Not yet re-proven on dev

- Biji-Biji tenant (landing + login + learner-dashboard)
- SOF tenant (landing + login + learner-dashboard)
- Non-primary Studio (/studio.*)
- Enterprise learner portal
- Admin console

### Not yet re-proven on prod (dev was exhausting enough this session)

- All surfaces — prod proof matrix is stale since 2026-04-09


## Update 2026-04-11 later: full 3-env matrix proof + 4 RCBs

**Proven this session via agent-browser:**

| Env | Tenant | Landing | Login flow | Dashboard | Account | Profile | Discussions | Comm. | Learner-rec |
|-----|--------|---------|-----------|-----------|---------|---------|-------------|-------|-------------|
| dev | mereka | L3 ✅ | L4 ✅ | L4 ✅ | L4 ✅ | 🔴 RCB-10 | 🔴 RCB-10 | 🔴 RCB-10 | L1 ✅ (auth redir) |
| dev | biji-biji | L3 ✅ | L4 ✅ | L4 ✅ | n/t | n/t | n/t | n/t | n/t |
| dev | SOF | L3 ✅ | L4 ✅ | L4 ✅ | n/t | n/t | n/t | n/t | n/t |
| prod | mereka | L3 ✅ | L4 ✅ | L4 ✅ | L4 ✅ | 🔴 RCB-10 | 🔴 RCB-10 | 🔴 RCB-10 | n/t |
| prod | biji-biji | L3 ✅ | 🔴 RCB-13 | — | — | — | — | — | — |
| prod | SOF | L3 ✅ | n/t | n/t | n/t | n/t | n/t | n/t | n/t |
| staging | mereka | L3 ✅ | 🔴 | — | — | — | — | — | — |

- **n/t** = not tested this session
- **RCB-10** = Paragon theme CSS files missing from MFE container — PR #1543
- **RCB-13** = Biji-Biji prod CSP blocks tenant CSRF endpoint — PR #1540
- **staging login** — testadmin doesn't exist on staging DB (not a platform bug)
- **RCB-11** — RESOLVED in current dev mfe image. learner-record dir exists, URL returns 200, L1 auth-redirect proven.

**Infrastructure tenant URL canonicality** (from `deploy/k8s/tenancy/tenant-registry.yaml`):
- Mereka prod: `academyv2.mereka.io` ✅
- Biji-Biji prod: `academy.biji-biji.com` ✅ (NOT `biji-biji.academyv2.mereka.io` — that's a migration target)
- SOF prod: `skillourfuture.academy.mereka.io` ✅ (NOT `skillourfuture.academyv2.mereka.io` — migration target)
- Dev uses `.academyv2.mereka.dev` tree for all 3 tenants
- Staging uses `.academyv2.mereka.io` (`staging.` prefix) for mereka, others TBD

**Staging operational verdict:** UP, not DOWN. Session 2's "externally unreachable" finding was cleared — staging.academyv2.mereka.io responds and renders Mereka landing. Cluster CPU is still overallocated per the staging audit agent. Staging is 2 commits behind prod on LMS image tag.

---

## Update 2026-04-11 later-later: PR #1562 merged + full 3-env L4 closure

**Merged this cycle:**
- #1536 (RCB-09 MFE_CONFIG footer/header keys) — 11:42Z

## Update 2026-04-11 08:10Z — deployed commit proof for the still-broken live surfaces

The fresh browser failures above are now tied to the exact deployed MFE revisions:

| Environment | Live namespace | Deployed MFE image tag | Deployed MFE digest | Contains fix? | Consequence |
|-------------|----------------|------------------------|---------------------|---------------|-------------|
| dev | `mereka-lms-dev` | `e4764d5834b6e24c26069e7edb2a527d05ae3b1d` | `sha256:9fff8d031b00feed62f1103baf21d2127c5f5721be064c6158aac018b3a15347` | **No `#1562`** | `/theme/core.min.css` still `404`; `Profile`, `Discussions`, `Communications` still broken live |
| prod | `mereka-lms` | `dfbe7ef318067917b6e3906da83cf3b98699dc22` | `sha256:4eee831c775f5705f92f5a0a274319d30b43cdfe8b21864cda06ab50ddaead94` | **No `#1540`** | Biji-Biji and SOF non-primary prod login still blocked live by old CSP |

**Ancestry proof**

- dev deployed commit `e4764d58...` is the merge commit of `#1543`
- dev deployed commit `e4764d58...` does **not** contain `#1562` merge commit `6fe23d71...`
- prod deployed commit `dfbe7ef3...` does **not** contain `#1540` merge commit `ff0a57f8...`

This means the remaining browser failures are currently explained by **deployed runtime lag**, not by contradictory browser evidence.
- #1540 (RCB-13 CSP tenant extra hosts) — 12:16Z
- #1543 (RCB-10 stage 1 build context sync) — 13:04Z
- #1562 (RCB-10 stage 2 production stage COPY inject) — 20:55Z

**New L4 proofs this later cycle (real browser via agent-browser):**

| Env | Surface | Level | Evidence |
|-----|---------|-------|----------|
| **staging** mereka | learner-dashboard | **L4** | lanea-platform-admin login → branded "Mereka Academy IN SESSION" + My Courses + Learning Cockpit rendered |
| **dev** mereka | `/learner-record/` | **L4** | testadmin login → "My Learner Records" heading + testadmin menu + Back to My Profile nav rendered. Program records API errors (no programs assigned) but MFE shell + auth intact. |
| **dev** biji-biji Studio | direct URL `apps.biji-biji.academyv2.mereka.dev/authoring/home` | **L3** | "Studio Biji-Biji Academy" branding + Biji-Biji logo + "Built for creators. Built for teams." tagline. L4 content fails with "Could not load Studio home" (dev data issue). |
| **dev** mereka Studio | `studio.academyv2.mereka.dev/` | **L4** | "Studio Mereka Academy" header, 41 courses listed (AI Fluency, MCT24-EN, etc.), New course / New library buttons. |
| **prod** mereka Studio | `studio.academyv2.mereka.io/home` | **L3 at Authentik** | Full OAuth chain Studio → LMS cms-sso → Authentik OIDC → branded "Welcome to Mereka" login page with Google SSO + email option. |

### Studio cross-tenant OAuth finding (non-blocking — RCB-16 candidate)

When visiting `studio.biji-biji.academyv2.mereka.dev/` with an active mereka session, the redirect chain lands on `apps.academyv2.mereka.dev/authoring/home` (MEREKA primary apps host) instead of `apps.biji-biji.academyv2.mereka.dev/authoring/home`. The displayed Studio header reads "Studio Mereka Academy" with MEREKA org courses.

Direct URL `apps.biji-biji.academyv2.mereka.dev/authoring/home` DOES serve the correct "Studio Biji-Biji Academy" branding. So the bug is in the Studio OAuth `redirect_uri` parameter — it returns users to primary apps host instead of tenant apps host.

Not blocking Phase 3 closure; documented as RCB-16 candidate for future investigation.

### Dev course data issue (RCB-15)

Every course on dev fails BlockStructureNotFound on `/api/course_home/outline` because `/openedx/media/` is mounted as `emptyDir` and the LMS pod restarts wipe block asset files. Not a platform bug — migration/data lane. Blocks Phase 2 L5 course content tests on dev. Escalated.

### Phase 4 staging L4 closure

Staging mereka is fully L4 operational via lanea-platform-admin. Previous Session 2 assessment of "externally unreachable" is firmly obsolete. Cluster CPU is still overallocated but the mereka tenant serves correctly.

### 2026-04-11 even-later: staging non-primary tenants landing-L3 proven, login-blocked by RCB-13

Real agent-browser probes against staging biji-biji + SOF non-primary tenants:

| Env | Tenant | Landing | Login flow | Notes |
|-----|--------|---------|------------|-------|
| staging | biji-biji | **L3 PROVEN** | 🔴 RCB-13 | "Biji-Biji Academy" branded header, tenant MFE URLs correct (`apps.staging.academy.biji-biji.com/authn/login`). Login shell loads, CSP blocks CSRF/mfe_context fetches to `staging.academy.biji-biji.com`. Same bug as prod RCB-13. |
| staging | SOF | **L3 PROVEN** | n/t (same CSP bug expected) | "Skill Our Future" branded header, tenant MFE URLs correct. |

**Current realized image tags (as of 2026-04-11 21:34Z)**:
- dev openedx: `e4764d583` (= #1543 only — missing #1536/#1540/#1562)
- staging openedx: `46a8c5913` (= #1393 — far behind)
- prod openedx: `dfbe7ef31` (= even older)

None of the three environments currently run the full RCB-09/10/13 fix set. All are waiting on an image build for the current main tip (`fd16b224` after #1492 merged at 22:55Z) to complete and propagate via Agent 2's promotion chain. Once realized, the matrix updates to:

- dev/staging/prod × mereka/biji-biji/SOF × login → L4 (RCB-13 cleared)
- dev/prod × mereka × profile/discussions/comms → L4 (RCB-10 cleared by stage 2 inject)
- Theme CSS 200 on `/theme/*` across all MFE hosts

Staging non-primary L4 login proof is **gated on realization**, not on a missing fix.

**Important finding 2026-04-11 22:30Z**: prod MFE image `dfbe7ef31806` ALREADY has `/openedx/dist/theme/` populated (16 files including `core.min.css`, `mereka-brand.min.css`, `biji-biji/`, `skillourfuture/`). So RCB-10 is **dev-only** regression that #1543 introduced when rewiring the theme sync pipeline; #1562 is the corrective fix but only affects dev. Prod was never broken on theme; prod login L4 proof from earlier session stands. Prod biji-biji login L4 is gated on #1540 (RCB-13 CSP) propagating to prod, not on theme.

### Build chain state 2026-04-11 22:57Z

- Build for `a3216e591` (#1563): Build MFE Image stuck at 78+ min (cold webpack reference is 44 min). Post-push OpenEdX Scan completed with **failure** (SBOM gen timed out 20m + Trivy install network error). Overall run would fail even if MFE succeeds → no auto-dispatch.
- Cancelled old build, new CI for `fd16b224` (post-#1492 merge) running. Build Tutor Images for fd16b224 will start after CI completes.
- **Lesson**: promotion chain is gated on successful Post-push scan. Transient network errors in SBOM/Trivy download will block the entire dispatch. Worth adding retry/graceful-degrade on scan failures if they're non-blocking vuln-wise.

---

## Update 2026-04-11 07:25Z — Agent 1 takeover correction

Fresh browser proof with the canonical learner accounts shows the live runtime is still behind the merged source fixes.

### Dev Mereka (live)

| Surface | Level | Current evidence |
|---------|-------|------------------|
| `/authn/login` | **L3** | Branded login shell renders. |
| Login (`lanea-mereka-learner`) | **L4** | Redirect completes to `/learner-dashboard/`; authenticated dashboard nav and account menu render. |
| `/learner-dashboard/` | **L4** | Visible dashboard content renders for the learner account. |
| `/u/lanea-mereka-learner` | **🔴 broken** | Title renders as `Learner Profile |`, but body is empty and the DOM never mounts visible content. |
| `/discussions/` | **🔴 broken** | React error boundary renders `An unexpected error occurred... Try again`. |
| `/communications/` | **🔴 broken** | Same React error boundary as Discussions. |
| `https://apps.academyv2.mereka.dev/theme/core.min.css` | **🔴 broken** | Live request still returns `HTTP 404`, zero bytes. |

**Correction:** the dev `RCB-10` family is still live. The merged `#1543` / `#1562` source fixes are not yet realized on the currently serving dev MFE runtime.

### Production non-primary tenants (live)

| Tenant | Surface | Level | Current evidence |
|--------|---------|-------|------------------|
| Biji-Biji | `/authn/login` | **L3** | Branded login shell renders. |
| Biji-Biji | Login (`lanea-bb-learner`) | **🔴 blocked** | Submit button flips to `pending` and never redirects to `/learner-dashboard/`. |
| SOF | `/authn/login` | **L3** | Branded login shell renders on `apps.skillourfuture.academyv2.mereka.io`. |
| SOF | Login (`lanea-sof-learner`) | **🔴 blocked** | Same `pending` stuck-login shape as Biji-Biji. |

Live CSP headers on both prod MFE hosts still show only the primary Mereka origins in `connect-src`, `img-src`, and `frame-src`:

- present: `https://academyv2.mereka.io`, `https://studio.academyv2.mereka.io`, `https://auth0.mereka.io`
- absent: `https://academy.biji-biji.com`, `https://skillourfuture.academy.mereka.io`

**Correction:** `RCB-13` is still live in production runtime. `#1540` is merged in git, but not realized on the current prod deployment.
