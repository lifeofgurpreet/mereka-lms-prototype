# SSO Canary

Authenticated canary checks that validate the full OIDC/Authentik SSO roundtrip against
LMS and Studio. These run in CI on a schedule and can be triggered manually.

## Overview

The SSO canary performs a real browser login using Python Playwright (Chromium headless)
and verifies:

1. **Primary OIDC canary** — a learner account logs in via Authentik, lands on LMS dashboard
   and MFE learner-dashboard. Validates `/api/user/v1/me` returns a session.
2. **Studio staff canary** — a staff account logs in via Authentik, then navigates to
   `https://studio.<domain>/home/` and verifies it loads without an error page.
3. **Local login canary** (optional) — same as primary but through the Authn MFE native form
   instead of Authentik. Disabled by default (`RUN_LOCAL_LOGIN_CANARY=0`).

## Where the canary runs

The `sso-canary` job is in `.github/workflows/smoke-authenticated.yml`. It runs:

- Every 6 hours via schedule
- On manual `workflow_dispatch` with `env_scope` input (`prod` / `dev` / `staging` / `both` / `all`)

The `operations-gates-runtime.yml` workflow also runs the canary as an optional credentialed
gate when `run_authenticated_sso_canary=true` is set.

For non-dispatch runs, `operations-gates-runtime.yml` resolves its environment scope from the
GitHub repository variable `OPERATIONS_GATES_RUNTIME_ENV_SCOPE` and falls back to `both` if the
variable is unset. For the current staging-proof lane, set this variable to `staging` before
re-enabling the workflow so the optional canary does not also require DEV secrets.

## Account policy

Use dedicated canary identities. Do **not** use a real operator mailbox such as
`team@mereka.io` for runtime proof.

Recommended identities:

- learner canary: `sso-canary` or an equivalent dedicated learner account
- Studio staff canary: `sso-canary-studio@mereka.io`

Why:

- real operator accounts carry real business context and permissions
- password rotation for proof should not disrupt human operators
- repo policy already forbids mutating real operator accounts for synthetic/runtime proof

## Secrets

All secrets are GitHub repository secrets. Never hardcode credentials.

### Primary OIDC canary (learner account)

| Secret | Description | Required |
|--------|-------------|----------|
| `SSO_CANARY_EMAIL_PROD` | Canary learner email for production | Yes (if running prod) |
| `SSO_CANARY_PASSWORD_PROD` | Canary learner password for production | Yes (if running prod) |
| `SSO_CANARY_EMAIL_DEV` | Canary learner email for dev | Yes (if running dev) |
| `SSO_CANARY_PASSWORD_DEV` | Canary learner password for dev | Yes (if running dev) |
| `SSO_CANARY_EMAIL_STAGING` | Canary learner email for staging | Yes (if running staging) |
| `SSO_CANARY_PASSWORD_STAGING` | Canary learner password for staging | Yes (if running staging) |
| `SSO_CANARY_EMAIL` | Fallback canary email (either env) | Optional |
| `SSO_CANARY_PASSWORD` | Fallback canary password (either env) | Optional |

### Studio staff canary

| Secret | Description | Required |
|--------|-------------|----------|
| `SSO_CANARY_STUDIO_EMAIL_PROD` | Studio staff email for production | Optional |
| `SSO_CANARY_STUDIO_PASSWORD_PROD` | Studio staff password for production | Optional |
| `SSO_CANARY_STUDIO_EMAIL_DEV` | Studio staff email for dev | Optional |
| `SSO_CANARY_STUDIO_PASSWORD_DEV` | Studio staff password for dev | Optional |
| `SSO_CANARY_STUDIO_EMAIL_STAGING` | Studio staff email for staging | Optional |
| `SSO_CANARY_STUDIO_PASSWORD_STAGING` | Studio staff password for staging | Optional |

The Studio canary is **non-blocking**: if the secrets are absent the run logs
`SKIP <env>: missing Studio SSO canary credentials (REQUIRE_STUDIO_CANARY=0)` and
continues without failing the workflow. Set `REQUIRE_STUDIO_CANARY=1` to make it blocking.

## Setting up Studio canary credentials

### 1. Create the canary account

The Studio canary account must be a **staff** user in Open edX (not a superuser or learner):

```bash
# Create via Django shell (requires cluster access)
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.create_user(
    username='studio-canary',
    email='studio-canary@mereka.io',
    password='<strong-random-password>',
    is_staff=True,
    is_active=True,
)
print('Created:', u.username)
"
```

The account must:
- Have `is_staff=True` (needed to access Studio `/home/`)
- Be enrolled via Authentik SSO (the canary logs in via OIDC, not native password)
- NOT have MFA enabled (or the canary flow will stall)
- Use an email address that exists in Authentik with a known password

### 2. Create the Authentik user

In the Authentik admin UI (`https://auth0.mereka.io`):
1. Create a new user with the same email as the Open edX staff account
2. Set a strong password — note it for the next step
3. Assign the user to the Open edX application / provider group
4. Verify the user can log in to Studio manually before adding the secret to CI

### 3. Add secrets to GitHub

```
Repository → Settings → Secrets and variables → Actions → New repository secret
```

Add each secret individually:
- `SSO_CANARY_STUDIO_EMAIL_PROD` = the email address
- `SSO_CANARY_STUDIO_PASSWORD_PROD` = the Authentik password

Repeat for `_DEV` and `_STAGING` variants if you want non-prod Studio proof in CI.

### 4. Verify in CI

Trigger the workflow manually:

```
Actions → "Authenticated Smoke Tests" → Run workflow → env_scope: prod|dev|staging
```

Look for `OK authenticated session validated` in the `sso-canary` job output.

## Environment variables (script-level)

The canary script `scripts/qa/verify-authenticated-sso-canary.sh` reads these env vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `REQUIRE_SECRETS` | `1` | Fail if primary OIDC credentials are missing |
| `REQUIRE_STUDIO_CANARY` | `0` | Fail if Studio credentials are missing |
| `RUN_OIDC_CANARY` | `1` | Run the primary OIDC login flow |
| `RUN_STUDIO_CANARY` | `1` | Run the Studio staff login flow |
| `RUN_LOCAL_LOGIN_CANARY` | `0` | Also run native /authn/login flow |
| `SSO_CANARY_TIMEOUT_SECONDS` | `180` | Playwright timeout per run |
| `SSO_CANARY_DEBUG` | `0` | Emit extra trace logging |
| `SSO_CANARY_IGNORE_HTTPS_ERRORS` | `auto` | `auto` = skip TLS verify on dev only |

## Troubleshooting

### `SKIP <env>: missing Studio SSO canary credentials`

The Studio secrets are not set in GitHub. Add `SSO_CANARY_STUDIO_EMAIL_PROD` /
`SSO_CANARY_STUDIO_PASSWORD_PROD` (and `_DEV` / `_STAGING` variants for non-prod)
per the setup steps above.

### `studio_access_required_but_not_authenticated`

The canary account reached Studio `/home/` but was redirected to `/signin`. Causes:
- Authentik user not in the Open edX application group
- Open edX account does not have `is_staff=True`
- Session cookie mismatch (check `studio_session_id` vs `sessionid` in MEMORY.md)

### `studio_error_page`

Studio returned a 500-class error page. Check:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=cms --tail=100
```

### `studio_complete_edx_oauth2_http_5xx`

Studio's OAuth2 callback endpoint returned a 5xx. Usually a misconfigured DOT
(Django OAuth Toolkit) client. Check `SOCIAL_AUTH_EDX_OAUTH2_*` settings in Studio
production.py and the DOT client record in LMS admin (`/admin/oauth2_provider/application/`).

### Screenshots and trace logs

Artifacts are uploaded to `sso-canary-<run_id>-<attempt>` in GitHub Actions. Screenshots
are saved as `<run_id>-failure.png` and `<run_id>-studio-failure.png`. The HTTP trace
log shows the full redirect chain (cookies redacted).

## Credential rotation

Rotate Studio canary credentials every 90 days or immediately after any credential
exposure. Procedure:
1. Reset the Authentik user password
2. Update `SSO_CANARY_STUDIO_EMAIL_PROD` / `SSO_CANARY_STUDIO_PASSWORD_PROD` in GitHub secrets
3. Trigger the canary manually to confirm it still passes
4. Update the rotation date below

**Last rotated**: (not yet set — initial setup pending)
**Next rotation**: 90 days after initial rotation

## Related

- Script: `scripts/qa/verify-authenticated-sso-canary.sh`
- Audit: `scripts/qa/audit-authenticated-sso-canary-wiring.sh`
- Workflow: `.github/workflows/smoke-authenticated.yml` (sso-canary job)
- Operations gate: `.github/workflows/operations-gates-runtime.yml`
- Credential handling: `docs/reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md`
- Studio SSO patterns: `MEMORY.md` (Studio SSO section)
