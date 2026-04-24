# Studio Auth JWT Closure

Date: 2026-03-15
Lane: S2 — Studio Auth Verification + JWT Source-of-Truth Closure

## Canonical Studio URL

Working path: `/authoring/home` on `apps.academyv2.mereka.dev`

The MFE config advertises `COURSE_AUTHORING_MICROFRONTEND_URL` as
`/course-authoring` but the MFE is built with webpack `PUBLIC_URL=/authoring`.
Only `/authoring/home` matches the React Router basename and renders content.
`/course-authoring/home` loads the HTML shell but renders blank (no route match).

## First Exact Blocker

CMS `JWT_PUBLIC_SIGNING_JWK_SET` contained a stale RSA public key
(`n=nyKlr...`) that did not match the actual `JWT_PRIVATE_SIGNING_JWK`
(`n=pupb_...`). PyJWT raised `InvalidAlgorithmError` when the CMS
tried to verify LMS-issued RS512 JWT cookies, causing all Studio MFE
API calls to return 401.

## JWT Source-of-Truth Comparison

| Setting | LMS | CMS (before fix) | CMS (after fix) |
|---------|-----|-------------------|-----------------|
| JWT_SIGNING_ALGORITHM | RS512 | RS512 | RS512 |
| public key n fingerprint | ae5895... | c19726... (STALE) | ae5895... |
| private key n fingerprint | ae5895... | ae5895... | ae5895... |
| pub == priv | TRUE | FALSE | TRUE |
| JWT_ISSUERS[0].SECRET_KEY | UeCMQQ... | rf4VGW... | rf4VGW... |

## Exact Fix

Replace hardcoded `JWT_PUBLIC_SIGNING_JWK_SET` with runtime derivation
from `JWT_PRIVATE_SIGNING_JWK` at startup in both LMS and CMS
`production.py`. This is the pattern already proven on the live LMS
patched configmap.

PR #926: `fix(auth): derive JWT public key from private key in LMS + CMS`

Live hotfix: CMS patched configmap updated + pod restarted.

## Live Re-Proof Result

- Login via `/authn/login`: PASS
- Navigate to `/authoring/home`: PASS
- Studio home renders with 109 courses: PASS
- Studio API `/api/contentstore/v1/home` returns 200: PASS
- No blocking 401 errors on content requests: PASS

## Audit Readiness

Studio is now functional through the intended auth flow.
The audit can proceed for Studio surfaces.
