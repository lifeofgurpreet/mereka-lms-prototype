# Auth Integration Contract: mereka-lms

## Ownership

1. Environment and deployment source of truth lives in: `k8s/bbi-infrastructure`
2. Canonical ownership matrix reference: `docs/AUTH_OWNERSHIP_MATRIX.md` (in `k8s/bbi-infrastructure`)
3. This repo owns service/chart capability only.
4. This repo does not own production environment auth values unless explicitly documented.

## Canonical Domains

- Authentik (prod): `https://auth0.mereka.io`
- Authentik (staging): `https://staging.auth0.mereka.io`
- Authentik (dev): `https://auth0.mereka.dev`
- Legacy reserved domain: `auth.mereka.io` (MUST NOT be used for new or active config)

## Service Auth Pattern

- Service: `mereka-lms`
- Pattern: `native-oidc`
- Domain(s): `academyv2.mereka.io,staging.academyv2.mereka.io,dev.academyv2.mereka.io`

## Required Runtime Configuration

- Required env vars:
  - `MEREKA_LMS_OIDC_CLIENT_ID`
  - `MEREKA_LMS_OIDC_CLIENT_SECRET`
- Secret source:
  - Infisical path: `/k8s/mereka-lms`
  - ESO target secret: `mereka-lms-secrets`

## Ingress Contract (Forward Auth Only)

If pattern is `forward-auth`, ingress MUST include:

```yaml
nginx.ingress.kubernetes.io/auth-url: "https://auth0.mereka.io/outpost.goauthentik.io/auth/nginx"
nginx.ingress.kubernetes.io/auth-signin: "https://auth0.mereka.io/outpost.goauthentik.io/start?rd=$scheme://$host$escaped_request_uri"
nginx.ingress.kubernetes.io/auth-response-headers: "Set-Cookie,X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid"
```

## OIDC Contract (Native OIDC / App-level OIDC)

If pattern uses OIDC:

- Issuer URL MUST be canonical Authentik URL
- Issuer/discovery path must be provider-specific (`/application/o/<slug>/`)
- Client secret MUST come from secret manager (not plaintext values files)

## Verification

- Local:
  - `rg -n 'OIDC_CLIENT_SECRET|OIDC_CLIENT_ID|SOCIAL_AUTH' . -g '!**/.git/**'`
  - `rg -n 'auth0.mereka|application/o/' docs scripts infrastructure deploy || true`
- Platform:
  - `auth-verify contract-check --format json`
  - `auth-verify drift-detect --format json`

## Change Management

- Any auth pattern/domain change requires:
  - Update in canonical infra repo
  - Update in auth registry/spec if needed
  - Evidence attached in PR
