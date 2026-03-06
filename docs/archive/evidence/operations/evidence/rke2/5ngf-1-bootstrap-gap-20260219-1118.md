# RKE2 Bootstrap Evidence (2026-02-19 11:18 UTC)

Commands and outputs summarized:

- `kubectl config get-contexts --output name`
  - `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
  - `kind-dev`
  - `rke2-nonprod`
  - `rke2-staging`

- `kubectl --context rke2-nonprod get ns | grep -i mereka-lms`
  - `mereka-lms  Active  10h`

- `kubectl --context rke2-staging get ns | grep -i mereka-lms`
  - `mereka-lms  Active  10h`

- `kubectl --context rke2-nonprod get app -n argocd | rg -i "mereka|lms|app"`
  - shows only generic they `mereka-*-staging-rke2` apps, no LMS ArgoCD application for LMS platform workloads.

- `kubectl --context rke2-staging get app -n argocd | rg -i "mereka|lms|app"`
  - same as above, no LMS platform ArgoCD app.

- `kubectl --context rke2-nonprod get deploy -n mereka-lms`
  - no resources

- `kubectl --context rke2-staging get deploy -n mereka-lms`
  - no resources

- `kubectl --context rke2-nonprod get externalsecret -n mereka-lms`
  - no resources

- `kubectl --context rke2-staging get externalsecret -n mereka-lms`
  - no resources

- `kubectl --context rke2-nonprod get service,ingress -n mereka-lms`
  - No resources found

- `kubectl --context rke2-staging get service,ingress -n mereka-lms`
  - No resources found

Conclusion:
RKE2 LMS workloads remain blocked at bootstrap/infrastructure level. The namespace exists but there is no LMS ArgoCD app targeting them-lms namespace, no LMS deployments, no external secrets, and no services/ingress to route prod-like hosts. This is an infra orchestration gap, not an application-config regression in this repo.
