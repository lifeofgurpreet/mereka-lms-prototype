# Auth Alert Runbook
_Audience: On-call/SRE • Owner: Engineering Lead • Last updated: 2026-02-09_

This is the remediation map for the auth-related alerts and checks in `infrastructure/monitoring/`.

## Quick Triage Checklist

1. Confirm the public auth surfaces:
   - `./scripts/qa/verify-auth-surfaces.sh prod`
2. If `/auth/login/oidc/` is 500ing:
   - `./scripts/qa/verify-oidc-provider-configs.sh`
3. If login works on one hostname but fails on another (microsite/alias):
   - `./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --verify`

## Alert → Likely Cause → Fix

| Alert / Signal | Likely Cause | Verify | Fix |
|---|---|---|---|
| **Authentik authorize 4xx (mereka-lms)** (`authentik-authorize-4xx-mereka-lms`) | Missing redirect URI in Authentik OAuth provider (new microsite/alias), or bad `redirect_uri` | `./scripts/qa/verify-auth-surfaces.sh prod` (checks Authentik accepts authorize URL) | `./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --apply` |
| **LMS OIDC provider disabled** (`lms-oidc-provider-disabled`) | Open edX `OAuth2ProviderConfig` drift (latest version disabled / not visible for site) | `./scripts/qa/verify-oidc-provider-configs.sh` | Create a new enabled provider config row (prefer additive); re-verify with the script |
| **OIDC token 400 (`Invalid client secret`)** (log signal) | OIDC secret drift between LMS runtime and effective `OAuth2ProviderConfig` secret resolution | `kubectl -n authentik logs deploy/authentik-server --since=2h \| rg -n 'client_id=mereka-lms\|Invalid client secret\|/application/o/token/'` plus `./scripts/qa/verify-oidc-provider-configs.sh --env prod` | Create a new latest OIDC provider config row with non-empty secret + expected display name; ensure LMS settings expose `SOCIAL_AUTH_OAUTH_SECRETS['oidc']` (supports `OIDC_CLIENT_SECRET` and `SOCIAL_AUTH_OIDC_SECRET`) |
| **OIDC login says `Your account is disabled`** | Active OIDC-linked LMS user has unusable password; third-party-auth pipeline blocks session cookie step | `./scripts/qa/verify-oidc-user-password-state.sh --env prod` | `./scripts/qa/verify-oidc-user-password-state.sh --env prod --fix`, then rerun credentialed canary |
| **Authenticated SSO canary failure** (`verify-authenticated-sso-canary`) | Real callback/session regression (bad creds, denied user, callback/token-exchange/session issues) | `SSO_CANARY_DEBUG=1 ./scripts/qa/verify-authenticated-sso-canary.sh --env prod` and inspect latest `var/auth-sso-canary/*-failure.png` | Verify canary creds are valid, confirm Authentik login stage policy allows canary user, re-run OIDC provider checks (`verify-oidc-provider-configs.sh`) and callback logs (`authentik-server` + LMS `/auth/complete/oidc/`) |
| **Authenticated SSO canary not running in runtime gates** | GitHub secret/variable wiring incomplete for runtime workflow | `./scripts/qa/audit-authenticated-sso-canary-wiring.sh` | Configure with `scripts/infra/configure-github-authenticated-sso-canary.sh --enable-runtime-gate`, then re-run strict audit (`STRICT=1 ...`) |
| **LMS CSRF failures** (`lms-csrf-failures`) | Cookie/CSRF domain/trusted origins drift after domain changes | Check `docs/operations/TROUBLESHOOTING.md` section “Login failures (CSRF 403...)” | Update `CSRF_TRUSTED_ORIGINS`, `CSRF_COOKIE_DOMAIN`, `SESSION_COOKIE_DOMAIN` in rendered config and restart lms/cms |
| **Auth verify CronJob failures** (`auth-verify-cronjob-failures`) | Public auth surface drift (DNS/cert, redirect chain, service outage) | `kubectl logs job/<latest> -n mereka-lms` (after GitOps deploy), or run `./scripts/qa/verify-auth-surfaces.sh prod` | Fix underlying cause; if it is redirect-uri: run `ensure-authentik-oidc-redirect-uris.sh --apply`; if it is OIDC provider drift: run `verify-oidc-provider-configs.sh` |
| **TLS cert expires soon** | Cert renewal needed / SAN mismatch | `./scripts/infra/check-cert-sans.sh` | Fix cert issuance/renewal; re-run checks |

## Notes (Non-Red-Flags)

- Discovery/Credentials/Ecommerce do **not** authenticate directly against Authentik. They do **LMS OAuth** (`/login/edx-oauth2/`), and the LMS itself uses Authentik OIDC. The correct verification is that they redirect to `https://<lms>/oauth2/authorize` and that LMS OIDC works.
