# Auth SSO Runbook (Authentik)

This runbook covers diagnosing and preventing regressions for **Authentik OIDC SSO** across:

- LMS (`academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`)
- Studio (`studio.*`)
- MFEs (`apps.*`)
- Service domains that proxy auth (`discovery.*`, `ecommerce.*`, `credentials.*`)

## Fast Checks (No Cluster Access)

Public surface contract (entrypoints, PKCE, cookie domains, Studio callback not-500):

```bash
./scripts/qa/verify-auth-surfaces.sh prod
```

## Credentialed End-to-End Canary (Browser, Real Login)

This validates the full login: Authentik -> LMS callback -> logged-in session.

### Run Locally (Infisical is Source of Truth)

```bash
./scripts/infra/run-authenticated-sso-canary-from-infisical.sh --env prod
```

Notes:
- This does **not** print secrets.
- Uses `/shared/oauth` canary creds (`GOOGLE_IMPERSONATE_EMAIL` / `GOOGLE_IMPERSONATE_PASSWORD`) as the test identity.

### Run in CI (GitHub Actions)

- Workflow: `.github/workflows/operations-gates-runtime.yml`
- Secrets: `SSO_CANARY_*`
- Gate variable: `RUN_AUTHENTICATED_SSO_CANARY=true`

Audit wiring (workflows + GitHub secret/variable presence):

```bash
./scripts/qa/audit-authenticated-sso-canary-wiring.sh
```

## Authentik Policy Exception Audit (Root-Cause for "Request Has Been Denied")

Authentik policy exceptions commonly surface as:
- "Request has been denied"
- "Unknown error"
- "The request failed and the interceptors did not return an alternative response"

Audit recent Authentik `policy_exception` events (OIDC-only filter on by default):

```bash
./scripts/qa/audit-authentik-policy-exceptions.sh --since 30m
```

If this fails, the cluster is not safe to treat as "healthy SSO" until fixed.

## Fix: Authentik Admin MFA Guard (Common Regression Vector)

If SSO breaks after Authentik hardening changes, re-apply the guarded admin-MFA policy:

```bash
./scripts/infra/ensure-authentik-admin-mfa.sh --apply
./scripts/infra/ensure-authentik-admin-mfa.sh --verify
```

The key invariant is the MFA policy **must not assume** Authentik request objects expose `request.path`
across versions; exceptions can break unrelated OIDC flows.

## Provider Configuration (LMS)

Verify OIDC provider configs are enabled/visible and secrets are non-empty:

```bash
./scripts/qa/verify-oidc-provider-configs.sh --env prod
```

## "Your Account Is Disabled" (OIDC Users)

Open edX can report "Your account is disabled" for OIDC users with unusable LMS passwords.

Audit:

```bash
./scripts/qa/verify-oidc-user-password-state.sh --env prod
```

Remediate (sets strong random passwords; does not print them):

```bash
./scripts/qa/verify-oidc-user-password-state.sh --env prod --fix
```

