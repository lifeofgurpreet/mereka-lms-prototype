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
  If `velero` CLI is not installed, create a Backup CR instead:
  ```bash
  name=pre-op-mereka-lms-$(date +%Y%m%d-%H%M)
  cat > /tmp/$name.yaml <<YAML
  apiVersion: velero.io/v1
  kind: Backup
  metadata:
    name: $name
    namespace: velero
  spec:
    includedNamespaces:
      - mereka-lms
    ttl: 720h0m0s
  YAML
  kubectl apply -f /tmp/$name.yaml
  kubectl -n velero get backup $name -o jsonpath='{.status.phase}{"\n"}'
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
  - Cookie scope is **per root domain** (mereka.io vs biji-biji.com). Avoid hardcoding a single cookie `Domain=` that would be invalid on other roots.
  - `CSRF_TRUSTED_ORIGINS` includes academyv2 + studio + apps + microsites
- [ ] Update OAuth redirect URIs (Google/Auth0) for new hostnames

## Secret Changes

- [ ] **Infisical is the only source of truth** – update secrets there first
- [ ] Pre-flight hygiene (fails on missing keys, placeholders, and CR/LF drift when strict):
  ```bash
  STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
  STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
  ```
- [ ] Verify secrets live under `/k8s/mereka-lms` (prod + dev), not `/`
  ```bash
  cd /home/gurpreet/projects/k8s/reka-slackbot
  infisical secrets --env prod --path /k8s/mereka-lms --domain https://secrets.mereka.io/api
  infisical secrets --env dev --path /k8s/mereka-lms --domain https://secrets.mereka.io/api
  ```
- [ ] MongoDB Atlas credentials:
  - `MEREKA_LMS_MONGODB_USERNAME`
  - `MEREKA_LMS_MONGODB_PASSWORD`
  - User must have `readWrite` on `openedx` + `cs_comments_service`
- [ ] Confirm sync to GCP Secret Manager (wait for GitHub Actions sync)
- [ ] Confirm ExternalSecrets refresh in K8s:
  ```bash
  kubectl get externalsecret -n mereka-lms
  kubectl describe externalsecret openedx-secrets -n mereka-lms
  ```
- [ ] Normalize MySQL password secrets (strip trailing CR/LF) so restarts cannot regress into MySQL `1045`:
  ```bash
  ./scripts/infra/normalize-mysql-secrets.sh
  APPLY=1 ./scripts/infra/normalize-mysql-secrets.sh
  ```
- [ ] Ensure optional service DBs exist (Notes/XQueue) after any MySQL secret rotation:
  ```bash
  ./scripts/infra/provision-mysql-app-dbs.sh
  ```
- [ ] Roll deployments if required:
  ```bash
  kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
  ```

## Post-release Verification

- [ ] `CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod`
- [ ] `CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod`
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
