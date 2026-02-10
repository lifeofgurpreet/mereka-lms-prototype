# Secret Rotation Checklist
_Audience: Platform / Security responders • Last updated: 2026-02-10_

Use this when a secret may have leaked or whenever scheduled credential rotation is due.

**Target**: Complete full rotation within 1 hour of incident declaration (DR-006).

## Full Rotation Procedure

Follow steps 1–5 below in order. Each step has verification commands.

## 1) Contain

1. Stop sharing logs/artifacts that may contain values.
2. Capture incident scope:
   - which key/credential
   - where it was exposed
   - affected systems (Infisical, GCP Secret Manager, K8s, third-party provider)

## 2) Rotate In Source Of Truth (Infisical)

1. Update the secret value in Infisical only.
2. Keep paths canonical:
   - shared admin creds: `/shared/oauth`
   - Mereka LMS app secrets: `/k8s/mereka-lms`

## 3) Propagate + Verify

1. Sync Infisical to GCP Secret Manager / K8s:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```
2. Verify expected keys exist in Infisical:
   ```bash
   STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
   STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
   ```
3. Verify runtime health after rollout:
   ```bash
   CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
   ./scripts/qa/verify-auth-hardening.sh
   ```

## 4) Invalidate Old Credentials

1. Disable/revoke the previous credential in provider systems (AWS/Stripe/Atlas/etc).
2. Confirm old credential can no longer authenticate.

## 5) Evidence + Closure

1. Run fast secret hygiene scan:
   ```bash
   STRICT=1 ./scripts/qa/scan-secrets-fast.sh
   ```
2. Confirm CI secret scan guard remains enabled (`trufflehog` in `.github/workflows/ci.yml`).
3. Document incident summary and rotated assets in the relevant bead.

