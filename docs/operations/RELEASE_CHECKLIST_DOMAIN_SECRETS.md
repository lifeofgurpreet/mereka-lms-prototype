# Release Checklist: Domain + Secret Changes
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-02-03_

Use this checklist for any domain or secret change on production (GKE). There is no staging environment; dev runs on kind (`academyv2.mereka.dev`).

## Pre-flight

- [ ] Confirm change window + notify stakeholders
- [ ] If any risky storage change is involved, run a Velero backup first:
  ```bash
  velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) \
    --include-namespaces mereka-lms --wait
  ```
- [ ] Pull latest repo + review diffs

## Domain Changes

- [ ] Update environment variables (`MEREKA_LMS_DOMAIN`, `MEREKA_DEV_DOMAIN`, etc.) in configmaps/overrides
- [ ] Update Caddy routing in `deploy/k8s/base/apps/caddy/Caddyfile`
- [ ] Update Cloudflare records in `infrastructure/cloudflare/records.json` (and `records.biji-biji.com.json` if needed)
- [ ] Apply DNS updates:
  ```bash
  CLOUDFLARE_ZONE_ID=... ./scripts/infra/cloudflare-sync.sh
  ```
- [ ] Verify TLS SANs:
  ```bash
  ./scripts/infra/check-cert-sans.sh
  ```
- [ ] Confirm cookies and CSRF:
  - `CSRF_COOKIE_DOMAIN=.academyv2.mereka.io`
  - `SESSION_COOKIE_DOMAIN=.academyv2.mereka.io`
  - `CSRF_TRUSTED_ORIGINS` includes academyv2 + studio + apps + microsites
- [ ] Update OAuth redirect URIs (Google/Auth0) for new hostnames

## Secret Changes

- [ ] **Infisical is the only source of truth** – update secrets there first
- [ ] Verify secrets live under `/k8s/mereka-lms` (prod + dev), not `/`
  ```bash
  cd /home/gurpreet/projects/k8s/reka-slackbot
  infisical secrets --env prod --path /k8s/mereka-lms --domain https://secrets.mereka.io/api
  infisical secrets --env dev --path /k8s/mereka-lms --domain https://secrets.mereka.io/api
  ```
- [ ] Confirm sync to GCP Secret Manager (wait for GitHub Actions sync)
- [ ] Confirm ExternalSecrets refresh in K8s:
  ```bash
  kubectl get externalsecret -n mereka-lms
  kubectl describe externalsecret openedx-secrets -n mereka-lms
  ```
- [ ] Roll deployments if required:
  ```bash
  kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
  ```

## Post-release Verification

- [ ] `CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod`
- [ ] `curl -I https://studio.academyv2.mereka.io` loads
- [ ] `curl -I https://apps.academyv2.mereka.io/authn/login` returns 200/302
- [ ] Microsites respond:
  - `https://academy.biji-biji.com`
  - `https://skillourfuture.academy.mereka.io`
- [ ] Studio login + course creation for each org

## Rollback Plan

- [ ] Revert DNS to previous IPs (Cloudflare)
- [ ] Roll back k8s manifests via Git
- [ ] Restore DB from latest Cloud SQL backup if required
