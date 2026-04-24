# RKE2 bootstrap check (2026-02-19 11:15 UTC)

## Command evidence

- `kubectl config get-contexts -o name`
  - `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
  - `kind-dev`
  - `rke2-nonprod`
  - `rke2-staging`

### rke2-nonprod
- `kubectl --context rke2-nonprod get ns`
  - namespace `mereka-lms` exists
- `kubectl --context rke2-nonprod get app -n argocd -o name`
  - LMS app is absent
  - apps present: `calcom-staging-rke2`, `cert-manager-dev-rke2`, `mereka-admin-staging-rke2`, `mereka-app-staging-rke2`, `mereka-auth-staging-rke2`, `mereka-backend-staging-rke2`, `mereka-checkout-staging-rke2`, `mereka-web-staging-rke2`, ...
- `kubectl --context rke2-nonprod get deploy -n mereka-lms`
  - no LMS deployments

### rke2-staging
- `kubectl --context rke2-staging get ns`
  - namespace `mereka-lms` exists
- `kubectl --context rke2-staging get app -n argocd -o name`
  - LMS app is absent
- `kubectl --context rke2-staging get deploy -n mereka-lms`
  - no LMS deployments

## Conclusion
RKE2 bootstrap blocker remains: LMS ArgoCD application and LMS workloads are not present in both `rke2-nonprod` and `rke2-staging`, despite namespaces existing.

## Action required
- Add LMS ArgoCD application to both rke2 overlays
- Wire ExternalSecrets/secret sync and deployment manifests for LMS stack
- Re-run 5ngf.1 evidence after app appears, then proceed with 5ngf.2 smoke.
