# Auth strategy — academyv2.mereka.dev

_Last updated 2026-04-24 (Faiz + Cowork autonomous probe)_

## TL;DR

**We do not need an OAuth app registration to ship Phase 0.** The right
sequence is:

1. **Today** — use the **public** course discovery API (no auth at all).
   This unlocks Discover, Course Detail preview, outline preview, and
   search immediately.
2. **Next** — move the SPA under a **`*.mereka.dev`** subdomain. The MFE
   JWT cookies that Open edX sets at `apps.academyv2.mereka.dev/authn/login`
   are scoped to `.mereka.dev`, so any SPA hosted on that zone can reuse
   them for authenticated endpoints. **No OAuth client id needed.**
3. **Only if we must stay on `mereka-lms-proto.netlify.app`** — ask
   Gurpreet to register a public PKCE OAuth2 client. This is the fallback,
   not the primary plan.

The frontend code already implements all three tiers; they flip on via
environment + hostname detection, so we don't have to rewrite anything
when the domain moves.

## What we verified on 2026-04-24

| Probe | Result | Implication |
|---|---|---|
| `GET https://academyv2.mereka.dev/` | 200 — full Mereka Academy landing page, sign-in link points to `apps.academyv2.mereka.dev/authn/` | Standard Open edX MFE auth is already live. |
| `GET https://academyv2.mereka.dev/oauth2/authorize/` (no params) | 302 → `/login` → `https://apps.academyv2.mereka.dev/authn/login?next=%2Foauth2%2Fauthorize%2F` | Django OAuth2 Provider is enabled. PKCE flow would work if we had a client id. |
| `GET /api/courses/v1/courses/` | 200 JSON, **41 courses**, fully public | Discover ships today, no auth. |
| `GET /api/user/v1/me` | 401 | "Who am I" needs session — matches cookie/JWT gate. |
| `GET /csrf/api/v1/token` | 200 JSON w/ `csrfToken` | Django CSRF exists for POSTs (enroll, profile update). |
| `GET /.well-known/openid-configuration` | 404 | No OIDC discovery doc — this is stock Open edX, which doesn't ship one. |

## Tier A — public, no auth (ready now)

| Feature | Endpoint | Notes |
|---|---|---|
| Discover page | `/api/courses/v1/courses/?page=N&page_size=12&search_term=…` | Pagination supported. |
| Course detail (preview) | `/api/courses/v1/courses/{course_id}` | Public card metadata. |
| Outline preview | `/api/courses/v2/blocks/?course_id=…&depth=all&block_types_filter=course,chapter,sequential,vertical` | Hidden blocks 404 — caught in `getCourseOutline`. |

In `frontend/src/api/client.js`, calls made with `{ auth: false }` skip the
`Authorization` header and `credentials: 'include'`, so the browser does a
simple CORS request — no preflight, no cookies.

## Tier B — cookie-mode (preferred authenticated path)

**Precondition:** the SPA is served from a host under `.mereka.dev`
(e.g. `academy.mereka.dev`, `app.mereka.dev`, `learn.mereka.dev`).

**Flow:**

1. User clicks **Sign in** in the SPA.
2. We redirect to `https://apps.academyv2.mereka.dev/authn/login?next=<spa-return-url>`.
3. User authenticates in the standard Mereka Academy login screen.
4. Open edX sets these cookies on `.mereka.dev`:
   - `edx-jwt-cookie-header-payload`
   - `edx-jwt-cookie-signature`
   - `sessionid`
   - `csrftoken`
5. User is 302'd back to the SPA. Because the SPA shares the parent zone,
   those cookies are visible. Every subsequent API call uses
   `credentials: 'include'` and authenticates via JWT — no token storage,
   no PKCE bookkeeping, no client id.
6. For state-changing requests (enroll, profile update), read `csrftoken`
   from `document.cookie` and echo it in `X-CSRFToken`.

**What Faiz needs to do:**

- In Netlify → *Site settings* → *Domain management* → add a custom
  subdomain of `mereka.dev` (suggestion: `academy.mereka.dev`).
- Add the DNS record (CNAME to `mereka-lms-proto.netlify.app`).
- Tell Gurpreet / LMS admin to add the new origin to
  **`CORS_ORIGIN_WHITELIST`** and **`LOGIN_REDIRECT_WHITELIST`** on the LMS.
  This is the only backend touch — a config change, not an OAuth app
  registration.

That's it. No new OAuth client. No secrets. No backend code changes.

## Tier C — fallback PKCE client (if we must stay on netlify.app)

If for any reason we cannot move off `mereka-lms-proto.netlify.app`:

1. Gurpreet adds a public OAuth2 client in Django admin:
   - `/admin/oauth2_provider/application/add/`
   - Client type: **Public**
   - Authorization grant type: **Authorization code**
   - `Skip authorization`: off
   - Redirect URIs:
     - `https://mereka-lms-proto.netlify.app/auth/callback`
     - `http://localhost:5173/auth/callback`
   - PKCE required: on (stock behaviour in recent Open edX)
2. Paste the client id into `VITE_OAUTH_CLIENT_ID`. The existing
   `oauth.js#login()` will auto-switch to PKCE when it sees a client id
   and is not under `*.mereka.dev`.

No backend code change is needed — this is a ~1-minute admin UI task.

## Why not just use ROPC (username/password grant)?

Open edX ships ROPC disabled in recent releases, and most tenants
explicitly block it. It also routes passwords through our SPA, which is a
security regression. Skip.

## CSRF for writes

Most reads are safe without CSRF. For writes (enrollment, profile, etc.):

```js
const csrf = document.cookie
  .split('; ')
  .find((c) => c.startsWith('csrftoken='))
  ?.split('=')[1];
await apiPost('/api/enrollment/v1/enrollment', { course_details: { course_id }},
  { headers: { 'X-CSRFToken': csrf } });
```

The `apiPost` wrapper already forwards arbitrary headers.

## Decision for this sprint

Go with **Tier A + planned Tier B**. Ship Discover today against real
academyv2 data, and queue the `academy.mereka.dev` DNS move as the next
unblocker. Tier C stays in the code as the fallback.
