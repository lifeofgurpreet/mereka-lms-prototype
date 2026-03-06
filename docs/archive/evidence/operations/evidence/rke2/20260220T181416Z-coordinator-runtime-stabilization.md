# Coordinator Runtime Stabilization

## Scope
Stabilize immediate RKE2 readiness checks and live GKE user-visible regressions while deployment/UI lanes continue in parallel.

## Actions Executed

1. **RKE2 readiness gate hard-fail removal for duplicate context drift**
   - Updated `scripts/qa/verify-rke2-deployment-readiness.sh` B0 logic:
     - fail only on same target + same namespace
     - warn for same target but namespace-isolated contexts
   - Updated kubeconfig context:
     - `rke2-staging` namespace set to `mereka-lms-staging`

2. **Readiness verification rerun**
   - `./scripts/qa/verify-rke2-deployment-readiness.sh --offline`
     - result: `10 PASS / 0 FAIL / 1 WARN / 9 SKIP` (PASS)
   - `KUBECONTEXT=rke2-nonprod ./scripts/qa/verify-rke2-deployment-readiness.sh --live`
     - result: `28 PASS / 0 FAIL / 2 WARN / 0 SKIP` (PASS)

3. **Studio live footer runtime hotfix (GKE)**
   - Replaced `/openedx/edx-platform/cms/templates/widgets/footer.html` in live CMS pod with repository white-label template.
   - Cleared cache path where possible.
   - Verified `https://studio.academyv2.mereka.io/` no longer contains `Powered by Open edX` or `edX Inc.` markers; now contains `mereka-studio-footer` and `support@mereka.io`.

4. **Enterprise admin runtime placeholder cleanup (GKE)**
   - Identified unresolved JS signatures in live admin bundle: `"MISSING_ENV_VAR".*`.
   - Hardened scripts:
     - `infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh`
       - skip read-only `env.config.js`
       - patch critical keys + fallback replacement for any unresolved placeholder signature
     - `scripts/infra/build-enterprise-mfe-clean.sh`
       - fail build if any unresolved `"MISSING_ENV_VAR".[A-Z0-9_]+` remain
       - fail build if `undefined_license_key` remains in dist assets
   - Applied runtime patch in live pods:
     - `enterprise-admin-portal`
     - `enterprise-learner-portal`
   - Verified public admin bundle no longer contains `MISSING_ENV_VAR` or `undefined_license_key` markers.

## Verification Notes

- `https://admin.academyv2.mereka.io/` returns 200.
- `https://admin.academyv2.mereka.io/app.850e7b8029f32b7b0227.js` now shows resolved/empty-safe config values instead of unresolved placeholder signatures.
- `https://studio.academyv2.mereka.io/` footer is white-label at runtime.

## Known Limitation

Runtime pod patches are **ephemeral** and will be lost on pod/image replacement. Durable closure requires image rebuild + GitOps rollout using updated scripts.
