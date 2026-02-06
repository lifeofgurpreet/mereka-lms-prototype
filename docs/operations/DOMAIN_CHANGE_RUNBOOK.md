# Domain Change Runbook (academyv2)
_Audience: Infra/SRE • Owner: Platform • Last verified: 2026-02-05_

This runbook enforces **zero-drift** changes for production (GKE) and dev (kind/VPS). There is **no staging** environment.

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
- [ ] Update domain constants in `deploy/k8s/base/apps/openedx/settings/lms/production.py`
- [ ] Update Caddy routes in `deploy/k8s/base/apps/caddy/Caddyfile`
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
- [ ] Apply k8s manifests + restart if needed.
- [ ] If image rebuilt, update tags and roll deployments.

## 5) Verification (Required)
```bash
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh dev
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
