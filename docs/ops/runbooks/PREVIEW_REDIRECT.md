# Preview Redirect — Operations Runbook

## Purpose

`preview.academyv2.mereka.io` was a staging/preview alias that has been retired.
This service replaces it with a static HTML page that auto-redirects visitors to
`https://academyv2.mereka.io/dashboard` after 3 seconds, with a manual link as
fallback.

## How It Works

| Component | Description |
|-----------|-------------|
| **ConfigMap** `preview-redirect-html` | Holds `index.html` with the redirect page |
| **Deployment** `preview-redirect` | Single nginx:1.27-alpine replica serving the ConfigMap |
| **Service** `preview-redirect` | ClusterIP on port 80 for ingress routing |

An Ingress rule (added in the production overlay) routes
`preview.academyv2.mereka.io → preview-redirect:80`.

## Manifests

```
deploy/k8s/base/apps/preview-redirect/
  configmap.yaml    — redirect HTML page
  deployment.yaml   — nginx deployment (nginx:1.27-alpine, 1 replica)
  service.yaml      — ClusterIP service on port 80
  kustomization.yaml
```

## Verifying the Redirect

```bash
# Static manifest check
./scripts/qa/verify-preview-redirect.sh

# Live check (requires kubectl + DNS)
curl -sI https://preview.academyv2.mereka.io | grep -i location
# Expected: Location: https://academyv2.mereka.io/dashboard
```

## Removing Once DNS Is Fully Deprecated

Once the `preview.academyv2.mereka.io` DNS record has been removed and traffic
has dropped to zero (confirm via Grafana / access logs):

1. Delete the Ingress rule from the production overlay.
2. Remove `preview-redirect` from the overlay `kustomization.yaml` resources list.
3. Delete `deploy/k8s/base/apps/preview-redirect/` entirely.
4. Commit and push — ArgoCD will garbage-collect the Deployment, Service, and
   ConfigMap automatically on the next sync.

Do **not** `kubectl delete` ArgoCD-managed resources directly (see
`~/.claude/rules/gitops-enforcement.md`).
