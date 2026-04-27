# Mereka LMS — SPA Frontend (Phase 0 foundation)

**Status:** Phase 0 scaffold. Router + auth + API client are real; every page is a stub that needs its prototype HTML ported + API wired.

This directory is a standalone Vite app. The sibling directories (`infrastructure/`, `scripts/`, `docs/`) are the Open edX backend — they are not touched by this frontend.

## Quick start

```bash
cd frontend
cp .env.example .env.local      # edit with real values when available
npm install
npm run dev                     # http://localhost:5173
```

On first run you'll see stub pages. That's expected — Phase 0 delivers the foundation; pages get real content in Phase 1+ tickets.

## Project layout

```
frontend/
├── index.html                  — Vite entry (tiny, just mounts #app)
├── vite.config.js              — dev server + build config
├── package.json
├── .env.example                — required env vars
└── src/
    ├── main.js                 — boot sequence
    ├── config.js               — reads env vars
    ├── api/
    │   ├── client.js           — fetch() wrapper with auth + 401 retry
    │   ├── courses.js          — /api/courses/v1/
    │   ├── users.js            — /api/user/v1/
    │   ├── enrollment.js       — /api/enrollment/v1/
    │   ├── progress.js         — /api/course_home/v1/ + /api/completion/v1/
    │   ├── certificates.js     — /api/certificates/v0/
    │   └── mocks/              — shape-compatible dev mocks
    ├── auth/
    │   ├── oauth.js            — OAuth2 Authorization Code + PKCE
    │   └── session.js          — sessionStorage token handling
    ├── router/
    │   ├── router.js           — History API router
    │   └── routes.js           — 17-page route table
    ├── pages/                  — one module per page (17 stubs)
    ├── components/             — reserved for shared header/avatar/notif
    └── styles/
        └── globals.scss        — Mereka brand tokens
```

## What's real vs stub in Phase 0

| Layer | State |
|---|---|
| Build pipeline (Vite) | ✅ Real |
| Router (17 pages, auth guards, History API) | ✅ Real |
| `window.goto(pageId)` legacy shim for ported HTML | ✅ Real |
| OAuth2 PKCE flow | ✅ Real — needs client_id from Open edX admin |
| API client + 401 handling | ✅ Real |
| API domain modules (shape + endpoints) | ✅ Real — toggle mocks with `VITE_USE_MOCK_DATA` |
| Page content | 🟡 Stubs — port HTML from `docs/design-reference/mereka-ux-prototype/index.html` per ticket |
| Styles | 🟡 Brand tokens only — port layout SCSS per page |

## Environment variables

| Var | Purpose | Source |
|---|---|---|
| `VITE_OPENEDX_BASE_URL` | Backend origin | Staging or prod tenant URL |
| `VITE_OAUTH_CLIENT_ID` | OAuth app id | `{base}/admin/oauth2_provider/application/` — ask Gurpreet/Malasari |
| `VITE_OAUTH_REDIRECT_URI` | PKCE callback | e.g. `https://learn.mereka.org/auth/callback` |
| `VITE_USE_MOCK_DATA` | Skip API calls, use mocks | `true` until backend OAuth is ready |

Set in:
- Local dev: `frontend/.env.local`
- Netlify: Site settings → Environment variables

## Backend expectations

The backend must:
1. Have an OAuth2 app registered with PKCE required, public client, authorization_code grant type.
2. Include the SPA's origin in `CORS_ORIGIN_WHITELIST` and `CSRF_TRUSTED_ORIGINS`.
3. Expose the standard Open edX REST endpoints (default).
4. (Phase 3) Have a `mereka_wishlist` Django app or equivalent.

## Ticket backlog

See `../docs/planning/LMS_Frontend_Backend_Integration_Plan.md` at the repo root for the full 40-ticket breakdown across EPIC-0 (Infra) → EPIC-4 (Commerce).

## Deployment

- **Phase 0 (this branch):** Netlify branch deploy — the `netlify.toml` at repo root builds `frontend/` when branch name matches `phase-0/*`.
- **When Phase 1 ships:** Flip root `netlify.toml` `[build]` block to point at `frontend/dist`, move the design-reference prototype to a separate branch/subsite, and cut over `mereka-lms-proto.netlify.app` (or the new `learn.mereka.org`).

## Porting pages from the prototype

For each page ticket:

1. Open `docs/design-reference/mereka-ux-prototype/index.html`.
2. Find the page's HTML block (search for the `goto(pageId)` target).
3. Copy the HTML into `frontend/src/pages/<id>.js` inside `render()`.
4. Extract page-specific CSS into `frontend/src/styles/<id>.scss` and import it from the page module.
5. Replace hardcoded data with calls into the `api/` module.
6. Remove `onclick="goto(...)"` inline handlers — router intercepts `<a href>` automatically.

The legacy `window.goto()` shim exists so you can port a page without rewriting every handler on day one.
