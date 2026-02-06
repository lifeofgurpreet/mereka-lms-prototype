# Domain Change Runbook (academyv2)
_Audience: Infra/SRE • Owner: Platform • Last verified: 2026-02-05_

This runbook enforces **zero-drift** changes for production (GKE) and dev (kind/VPS). There is **no staging** environment.

## Source Of Truth (No Drift)

Production (`academyv2.mereka.io`) is **GitOps-managed by ArgoCD** from the `bbi-infrastructure` repo:
- Repo: `Biji-Biji-Initiative/bbi-infrastructure`
- Path: `apps/mereka-lms/overlays/prod`
- Argo app: `mereka-lms-local` (namespace `argocd`)

Do **not** run `kubectl apply -k deploy/k8s/...` against production. Those changes will be overwritten by Argo self-heal.

This repo (`mereka-lms`) remains the source of truth for:
- Dev/kind manifests under `deploy/k8s/` (VPS kind cluster)
- Theme sources under `infrastructure/tutor/themes/`
- Operator verification scripts under `scripts/`

## Scope
- academyv2.mereka.io (+ studio/apps/discovery/ecommerce/notes/credentials/forum)
- skillourfuture.academy.mereka.io
- academy.biji-biji.com
- dev: academyv2.mereka.dev (+ subdomains)

## Pre-flight (Required)
- [ ] Pull latest repo and review diffs.
- [ ] If any storage change: run a Velero backup.
  ```bash
  velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) \
    --include-namespaces mereka-lms --wait
  ```
- [ ] Confirm Infisical canonical path:
  ```bash
  ./scripts/infra/infisical-audit-mereka-lms.sh
  ```

## 1) Update configs
- [ ] Production (GitOps): update `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/*`
- [ ] Dev (kind): update `deploy/k8s/*` in this repo
- [ ] Ensure domain constants + routing are aligned across:
  - Open edX settings (`production.py`)
  - Caddy host routing (forum/credentials/ecommerce/discovery/notes)
- [ ] Ensure cookies/CSRF:
  - Cookie scoping is **per root domain** (mereka.io vs biji-biji.com); do not hardcode a single Domain that would be invalid on other roots.
  - `CSRF_TRUSTED_ORIGINS` includes all served hosts and microsites.

## 2) DNS + TLS
- [ ] Update Cloudflare records:
  ```bash
  CLOUDFLARE_ZONE_ID=... ./scripts/infra/cloudflare-sync.sh
  ```
- [ ] Verify TLS SANs:
  ```bash
  ./scripts/infra/check-cert-sans.sh
  ```

## 3) OAuth/OIDC
- [ ] Authentik redirect URIs include:
  - `https://academyv2.mereka.io/*`
  - `https://apps.academyv2.mereka.io/*`
  - `https://studio.academyv2.mereka.io/*`
  - `https://academy.biji-biji.com/*`
  - `https://skillourfuture.academy.mereka.io/*`
- [ ] LMS OAuth2 clients updated (ecommerce/credentials/discovery).

## 4) Deploy
- [ ] Production: commit + push to `bbi-infrastructure` (ArgoCD applies automatically).
- [ ] Dev: apply k8s manifests to kind.
- [ ] If image rebuilt, update tags and roll deployments.

## 5) Verification (Required)
```bash
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh dev

# Keep the expected hostname inventory honest (prod + dev)
./scripts/qa/list-openedx-hostnames.sh
```
- [ ] Validate Authn MFE login + account/profile redirects.
- [ ] Validate Studio course creation.

## Rollback
- [ ] Revert DNS records (Cloudflare).
- [ ] Revert repo changes and re-apply k8s.
- [ ] Restore DB from last backup if required.

## References
- `docs/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`
- `docs/operations/ACCESS_URLS.md`
- `docs/operations/TROUBLESHOOTING.md`
