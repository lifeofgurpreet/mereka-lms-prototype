# Enterprise Auth Runtime Contract

> Priority 4 — formalize the auth/CSRF/cookie/proxy contract so it stops reappearing as regressions.

## The Contract

This document defines the exact runtime auth contract for enterprise learner and admin
authenticated flows. Any deviation from this contract is a bug.

## 1. Cookie Contract

### Session Cookies

| Property | LMS | CMS/Studio | Enterprise MFEs |
|----------|-----|-----------|-----------------|
| Cookie name | `sessionid` | `studio_session_id` | N/A (no own session) |
| Cookie domain | `.academyv2.mereka.{io,dev}` | `None` (host-only) | N/A |
| SameSite | `None` | `None` | N/A |
| Secure | `true` | `true` | N/A |
| HttpOnly | `true` | `true` | N/A |

### JWT Cookies (issued by LMS)

| Property | Value | Notes |
|----------|-------|-------|
| Header+Payload cookie | `edx-jwt-cookie-header-payload` | Readable by JS (not HttpOnly) |
| Signature cookie | `edx-jwt-cookie-signature` | HttpOnly, not readable by JS |
| Domain | `.academyv2.mereka.{io,dev}` | Shared across LMS + enterprise MFE subdomains |
| SameSite | `None` | Required for cross-subdomain auth |
| Secure | `true` | Required when SameSite=None |
| Path | `/` | Available on all paths |
| Set by | LMS `/login_refresh` endpoint | Called by MFE `@edx/frontend-platform` |

### CSRF Cookies

| Service | Cookie Name | Domain | Notes |
|---------|------------|--------|-------|
| LMS | `csrftoken` | `.academyv2.mereka.{io,dev}` | Shared with enterprise-access BFF |
| CMS/Studio | `csrftoken` | host-only | Separate from LMS |
| enterprise-access | `csrftoken` | Not set by service (uses LMS cookie) | **MUST match LMS** — setting `CSRF_COOKIE_NAME='csrftoken'` in config-gen |
| enterprise-catalog | N/A | N/A | No browser-facing POST endpoints |
| enterprise-subsidy | N/A | N/A | No browser-facing POST endpoints |

**Critical rule**: enterprise-access MUST use `CSRF_COOKIE_NAME='csrftoken'` so that
the LMS-issued CSRF cookie is recognized by Django's `enforce_csrf()` when MFE Caddy
proxies BFF POST requests with `Host=<lms-host>`.

## 2. CSRF Trusted Origins

### LMS

```python
CSRF_TRUSTED_ORIGINS = [
    'https://academyv2.mereka.io',
    'https://apps.academyv2.mereka.io',
    'https://admin.academyv2.mereka.io',
    'https://learner.academyv2.mereka.io',
    # dev equivalents...
]
```

### enterprise-access

```python
CSRF_TRUSTED_ORIGINS = [
    'https://academyv2.mereka.dev',           # LMS
    'https://learner.academyv2.mereka.dev',   # Learner portal origin (Referer)
    'https://admin.academyv2.mereka.dev',     # Admin portal origin (Referer)
]
```

**Why**: MFE Caddy proxies BFF POST requests with `Host=<lms-host>` but the browser's
`Referer` header contains the MFE origin. Django CSRF checks require `Referer` origin
to match either `Host` or `CSRF_TRUSTED_ORIGINS`.

## 3. Proxy Chain

### Enterprise Admin Portal (authenticated)

```
Browser (https://admin.academyv2.mereka.dev)
  → Ingress (TLS termination)
  → Caddy (port 80, inside admin-portal pod)
    ├── /api/v1/bffs/*  → enterprise-access:18270  (BFF endpoints)
    ├── /api/*          → lms:8000                  (LMS API)
    ├── /csrf/*         → lms:8000                  (CSRF token)
    ├── /login_refresh  → lms:8000                  (JWT refresh)
    └── /*              → file_server (static React)
```

### Enterprise Learner Portal (authenticated)

```
Browser (https://learner.academyv2.mereka.dev)
  → Ingress (TLS termination)
  → Caddy (port 80, inside learner-portal pod)
    ├── /api/v1/bffs/*  → enterprise-access:18270  (BFF endpoints)
    ├── /api/*          → lms:8000                  (LMS API)
    ├── /csrf/*         → lms:8000                  (CSRF token)
    ├── /login_refresh  → lms:8000                  (JWT refresh)
    └── /*              → file_server (static React)
```

### Key Caddy Behaviors

| Behavior | Setting | Why |
|----------|---------|-----|
| Host header to LMS | `header_up Host {$LMS_HOST}` | LMS needs correct Host for tenant resolution |
| Host header to enterprise-access | `header_up Host {$LMS_HOST}` | enterprise-access CSRF checks Host against trusted origins |
| X-Forwarded-Proto | `header_up X-Forwarded-Proto https` | Django `request.is_secure()` must return True |
| Cookie passthrough | Default (no stripping) | JWT + CSRF cookies must reach backends |

## 4. Login Flow

### Enterprise Learner Login

```
1. Browser → https://learner.academyv2.mereka.dev/
2. MFE loads, @edx/frontend-platform calls /login_refresh
3. Caddy proxies /login_refresh → lms:8000
4. LMS checks session cookie → no session → 401
5. MFE redirects to LMS login: https://academyv2.mereka.dev/login?next=...
6. User authenticates (directly or via Authentik SSO)
7. LMS sets session cookie (domain=.academyv2.mereka.dev)
8. LMS redirects back to learner portal
9. MFE calls /login_refresh again
10. LMS finds session → issues JWT cookies (domain=.academyv2.mereka.dev)
11. MFE reads edx-jwt-cookie-header-payload → authenticated
12. MFE calls /api/v1/bffs/learner/dashboard with JWT cookie
13. Caddy proxies to enterprise-access:18270 with Host=LMS_HOST
14. enterprise-access validates JWT → resolves enterprise context → responds
```

### Critical JWT Details

| Property | Value |
|----------|-------|
| Algorithm | RS512 (signing), HS256 (fallback verification) |
| Issuer | `https://academyv2.mereka.{io,dev}/oauth2` |
| Audience | `openedx` |
| Public key | Derived from `JWT_PRIVATE_SIGNING_JWK` at LMS startup |
| Shared secret | `JWT_SECRET_KEY` (symmetric fallback) |

**Rule**: All enterprise services MUST derive `JWT_PUBLIC_SIGNING_JWK_SET` from the same
private key as LMS. Hardcoded public keys WILL drift.

## 5. CSRF-Sensitive Endpoints

| Service | Endpoint | Method | CSRF Required |
|---------|----------|--------|---------------|
| enterprise-access | `/api/v1/bffs/learner/dashboard` | POST | Yes |
| enterprise-access | `/api/v1/bffs/admin/dashboard` | POST | Yes |
| LMS | `/api/enrollment/v1/enrollment` | POST | Yes |
| LMS | `/csrf/api/v1/token` | GET | No (issues token) |
| LMS | `/login_refresh` | POST | No (session-based) |

## 6. Verification Script

### Location

`scripts/qa/verify-enterprise-auth-contract.sh` (to be created)

### Checks

```bash
#!/usr/bin/env bash
# Verify enterprise auth runtime contract

# 1. JWT cookie domain matches across LMS and MFE
# 2. CSRF cookie name matches between LMS and enterprise-access
# 3. CSRF_TRUSTED_ORIGINS includes MFE origins
# 4. enterprise-access config-gen produces correct CSRF_COOKIE_NAME
# 5. Caddy forwards Host header correctly
# 6. /login_refresh is proxied to LMS (not blocked)
# 7. /api/v1/bffs/* is proxied to enterprise-access (not LMS)
# 8. JWT_PUBLIC_SIGNING_JWK_SET is derived (not hardcoded) in all services
```

### Browser Proof Harness (manual)

```bash
# Step 1: Get CSRF token
CSRF=$(curl -s -c cookies.txt https://learner.academyv2.mereka.dev/csrf/api/v1/token | jq -r .csrfToken)

# Step 2: Login via LMS (requires session)
# Manual: authenticate in browser, extract cookies

# Step 3: Call BFF with JWT + CSRF
curl -b cookies.txt \
  -H "X-CSRFToken: $CSRF" \
  -H "Content-Type: application/json" \
  -X POST \
  https://learner.academyv2.mereka.dev/api/v1/bffs/learner/dashboard \
  -d '{"enterprise_customer_slug": "mereka"}'

# Expected: 200 with enterprise context
# Failure modes:
# - 403: CSRF token mismatch (cookie name or trusted origins wrong)
# - 401: JWT invalid (public key drift or issuer mismatch)
# - 502: Caddy can't reach enterprise-access (routing wrong)
# - 404: BFF endpoint not found (wrong service or URL)
```

## 7. Contract Violations That Have Occurred

| Date | Violation | Root Cause | Fix |
|------|-----------|-----------|-----|
| 2026-03 | CSRF 403 on BFF POST | enterprise-access used `enterprise_access_csrftoken` instead of `csrftoken` | Set `CSRF_COOKIE_NAME='csrftoken'` in config-gen |
| 2026-03 | JWT signature invalid | Public JWK was hardcoded, drifted from private key | Derive public JWK from private key at startup |
| 2026-03 | Studio session collision | Studio used `sessionid` (same as LMS) | Changed to `studio_session_id` |
| 2026-03 | CSRF Referer mismatch | MFE origin not in `CSRF_TRUSTED_ORIGINS` | Added `learner.*` and `admin.*` to trusted origins |

## 8. Non-Negotiable Rules

1. **CSRF_COOKIE_NAME on enterprise-access MUST be `csrftoken`** — same as LMS
2. **JWT public key MUST be derived from private key** — never hardcoded separately
3. **Caddy MUST forward Host header as LMS hostname** — for CSRF Referer/Host match
4. **Cookie domain MUST be `.academyv2.mereka.{io,dev}`** — for cross-subdomain JWT sharing
5. **SameSite MUST be `None`** — for cross-subdomain cookie sending
6. **All enterprise services MUST list MFE origins in CSRF_TRUSTED_ORIGINS** — if they serve browser POST requests
7. **Session cookie name MUST be unique per service** — to prevent session collision
