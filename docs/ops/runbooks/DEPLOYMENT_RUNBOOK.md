# Deployment Runbook – Mereka LMS (academyv2.mereka.io)
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-02-07_

This runbook captures the steps to roll out the nightly Open edX stack on Google Cloud in the new `mereka-lms` project. Environment model: **production (GKE)** + **dev (kind/VPS)** only; “staging” bucket names are legacy production labels.

## 1. Prerequisites

- Billing enabled for `mereka-lms` (user to attach existing billing account).
- CLI auth: `gcloud auth login` and `gcloud auth application-default login`.
- Enable Google APIs:
  ```bash
  gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    sqladmin.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    dns.googleapis.com \
    secretmanager.googleapis.com
  ```
- MongoDB Atlas account (or decide on self-managed alternative) reachable from GCP.

## 2. Terraform workflow

1. `cd infrastructure/terraform` and create `terraform.tfvars`:
   ```hcl
   project_id  = "mereka-lms"
   domain_root = "academyv2.mereka.io"
   ```
   Add any secret definitions to the `module "secret_manager"` block via tfvars rather than committing to Git.
2. Implement each module under `modules/` (included in repo).

Reality-first note:
- Production currently runs **in-cluster MySQL/Redis (PVC-backed)**, so Cloud SQL / Memorystore are not required for the current architecture.
- Avoid hardcoding private IPs in configs; prefer K8s service DNS (`mysql`, `redis`).

Modules:
   - `network`: VPC + subnets + secondary ranges for Autopilot.
   - `gke`: Autopilot cluster (Workload Identity, release channel regular).
   - `artifact_registry`: regional Docker repo `asia-southeast1/openedx`.
   - `storage`: buckets for uploads (`lms-content`), blockstore (`lms-blockstore`), backups (`lms-backup`).
   - `secret_manager`: placeholder secrets (Django key, JWT private key, DB creds, SMTP creds).
3. `terraform init`, `terraform plan`, `terraform apply` once modules are filled.
4. Record outputs (cluster endpoint, bucket names, secret IDs).
   ```bash
   terraform output
   ```
   Do not copy/paste private IPs into app configs; use `mysql`/`redis` service DNS.

## 3. Tutor configuration

1. Copy `infrastructure/tutor/config.example.yml` to `tutor_env/config.yml` and adjust (do not copy secret values into git):
   - `LMS_HOST`: `academyv2.mereka.io`
   - `CMS_HOST`: `studio.academyv2.mereka.io`
   - `MFE_HOST`: `apps.academyv2.mereka.io`
   - `MFE_DOCKER_IMAGE`: `ghcr.io/biji-biji-initiative/mereka-lms/mfe:nightly` (post-build)
   - `ECOMMERCE_DOCKER_IMAGE`: `ghcr.io/biji-biji-initiative/mereka-lms/openedx-ecommerce:12.0.4`
   - `ECOMMERCE_WORKER_DOCKER_IMAGE`: `ghcr.io/biji-biji-initiative/mereka-lms/openedx-ecommerce-worker:12.0.4`
   - `XQUEUE_DOCKER_IMAGE`: `ghcr.io/biji-biji-initiative/mereka-lms/openedx-xqueue:12.1.0`
   - `MONGODB_URI`: Atlas connection string (for forum and the Atlas-only target state).
   - Configure external service endpoints (GCS buckets, etc). For DB/cache, prefer in-cluster service DNS.
   - For additional LMS domains (microsites), see `docs/concepts/architecture/MULTISITE.md` and re-run `./infrastructure/tutor/apply-patches.sh` so Caddy/Nginx/Django trust the new hostnames.
2. Store sensitive values in Secret Manager and inject at runtime via Tutor environment overrides (e.g. `tutor config save --set MYSQL_HOST=...`).
3. Prepare Kubernetes overrides, e.g. `tutor config save --set K8S_NAMESPACE=mereka-lms` and `tutor config save --set REGISTRY_URL=ghcr.io/biji-biji-initiative/mereka-lms`.

## 4. Build & push images

1. Authenticate Docker with Artifact Registry:
   ```bash
   gcloud auth configure-docker asia-southeast1-docker.pkg.dev
   ```
2. Build Tutor images:
   ```bash
   source infrastructure/tutor/tutor-env.sh
   ./infrastructure/tutor/apply-patches.sh
   tutor images build all
   tutor images push all --repository ghcr.io/biji-biji-initiative/mereka-lms
   ```
   (Ensure `MFE_DOCKER_IMAGE` is updated before pushing.)

## 5. Deploy to GKE Autopilot

1. Generate Kubernetes config:
   ```bash
   source infrastructure/tutor/tutor-env.sh
   tutor k8s quickstart --non-interactive
   ```
2. Apply secrets via Secret Manager CSI or Kubernetes secrets populated from `gcloud secrets versions access`.
3. Deploy resources:
   ```bash
   tutor k8s init
   tutor k8s start
   ```
4. MongoDB (production): Atlas-only. Keep `MONGODB_HOST` wired to `openedx-secrets/FORUM_MONGODB_SRV` and ensure legacy `Service/mongodb` remains removed via production overlay patching (see `docs/concepts/architecture/ARCHITECTURE_MONGODB.md`).
5. Verify pods: `kubectl get pods -n mereka-lms`.
6. Provision HTTPS certificates (either Tutor Let’s Encrypt or Cloud Load Balancer + managed cert). Update DNS records in Cloud DNS zone `academyv2-mereka-io`.
   - Cloudflare automation: `CLOUDFLARE_ZONE_ID=0f75c87585234a3b4b265a0973944736 ./scripts/infra/cloudflare-sync.sh` keeps the `academyv2`, `studio.academyv2`, and `apps.academyv2` hostnames pointed at the GKE ingress (records defined in `infrastructure/cloudflare/records.json`). Provide either `CLOUDFLARE_API_TOKEN` *or* the `CLOUDFLARE_EMAIL` + `CLOUDFLARE_API_KEY` pair.
   - Certificate hygiene: the same JSON also enforces a `CAA 0 issue "letsencrypt.org"` record on `academyv2.mereka.io` so only Let’s Encrypt can mint certs for the academyv2 sub-tree. Follow up with `./scripts/infra/cloudflare-harden-zone.sh` to keep TLS min version at 1.2, `ssl=strict`, `always_use_https=on`, and HSTS enabled across subdomains.

## 6. Post-deploy tasks

- Create superuser:
  ```bash
  tutor k8s do createuser gurpreet@biji-biji.com \
    gurpreet@biji-biji.com --staff --superuser --password-from-env SUPERUSER_PASSWORD
  ```
  (Set the password via Secret Manager or prompt; never commit credentials.)
- Smoke test LMS, Studio, Discovery, MFEs (`./scripts/qa/smoke-test.sh` covers the public endpoints).
- Configure backups (Velero-driven):
  - Audit posture: `./scripts/qa/audit-velero.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
  - Pre-op backup before risky operations:
    `velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait`
  - Docs: `docs/operations/VELERO_BACKUP_AUDIT.md`, `docs/ops/runbooks/DISASTER_RECOVERY.md`
- Store long-lived secrets in Google Secret Manager so CI and operators pull values without editing `tutor_env/config.yml` directly. Minimum list: Django secret key, JWT private key, LMS superuser password, SMTP password, and Atlas host/user/password inputs for `FORUM_MONGODB_SRV`. Add new values with `gcloud secrets versions add NAME --data-file=-` and reference them via `tutor config save --set KEY="$(gcloud secrets versions access ...)"`.
- Apply the Mereka branding pack after each upgrade:
  ```bash
  ./scripts/branding/sync-brand-assets.sh
  tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
  ./infrastructure/tutor/apply-patches.sh
  tutor images build openedx && tutor images build mfe
  ```
  The patch step copies the SCSS/fonts into the Indigo MFE build so all micro-frontends share the same palette.
- Hook monitoring dashboards/alerts (see `docs/ops/monitoring/MONITORING.md` + JSON templates in `infrastructure/monitoring/`).
- Review the DR runbook and backup cadence in `docs/ops/runbooks/DISASTER_RECOVERY.md`.
- Enforce cost guardrails via Terraform budgets. Populate `billing_account_id`, `monthly_budget_myr`, and `budget_thresholds` in `infrastructure/terraform/terraform.tfvars`, then apply:
  ```bash
  cd infrastructure/terraform
  terraform init
  GOOGLE_CLOUD_QUOTA_PROJECT=mereka-lms terraform apply -target=google_billing_budget.mereka_monthly
  ```
  This provisions a Cloud Billing budget with alert thresholds (default 62.5% and 100%). Add notification channel resource names to `budget_monitoring_channels` if you want alerts to hit `techadmin@biji-biji.com` via Cloud Monitoring.

## 7. GitHub integration

- Repo: `https://github.com/Biji-Biji-Initiative/mereka-lms` (remote `origin` already configured locally).
- Backups: Cloud SQL backup workflow is legacy and manual-only. Production backups are Velero-driven (see `docs/operations/VELERO_BACKUP_AUDIT.md`).
- Next pipeline work: add workflows for (a) Tutor image build/push + smoke tests and (b) Terraform plan/apply with manual approvals. Store any additional credentials (Artifact Registry robot, MongoDB Atlas API, etc.) as repo secrets instead of committing them here.

## 8. Cutover checklist

- Domains pointing to the GCLB IP.
- TLS certificates valid.
- Admin login verified.
- Email (SMTP) smoke test.
- Backup job success recorded.

> Track outstanding tasks/issues in the repo’s issue tracker to keep the deployment plan auditable.

---

## 9. Enterprise MFE Build → Push → GitOps → Rollout

### Overview

Enterprise MFE images (`enterprise-admin-portal`, `enterprise-learner-portal`) are derivative builds
of the upstream Open edX enterprise MFEs. They are built clean (no NREUM browser agent) via
`infrastructure/docker/enterprise-mfe-clean/` and pinned in the production kustomization.

**No runtime initContainer workaround is needed.** NREUM is stripped at Docker build time.

### Build flow

```bash
# 1. Build NREUM-clean images and push to GCR
bash scripts/infra/build-enterprise-mfe-clean.sh [source_tag]
# Output: enterprise-admin-portal:nreum-clean-YYYYMMDDHHMI
#         enterprise-learner-portal:nreum-clean-YYYYMMDDHHMI

# 2. Note the generated tag (printed at end of script as "Clean tag: ...")
CLEAN_TAG="nreum-clean-YYYYMMDDHHMI"  # replace with actual output

# 3. Update production kustomization (deploy/k8s/overlays/production/kustomization.yaml):
#    images:
#      - name: .../enterprise-admin-portal
#        newTag: $CLEAN_TAG
#      - name: .../enterprise-learner-portal
#        newTag: $CLEAN_TAG

# 4. Commit + push + ArgoCD sync
git add deploy/k8s/overlays/production/kustomization.yaml
git commit -m "chore(enterprise-mfe): pin clean enterprise MFE images to $CLEAN_TAG"
git push
argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal
argocd app sync mereka-lms --resource apps:Deployment:enterprise-learner-portal
```

### Post-deploy smoke

```bash
# Verify NREUM clean + HTTP 200 + routing
bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh
# Expected: PASS 9/0/0

# Manual spot checks
curl -sI https://admin.academyv2.mereka.io/
curl -s https://admin.academyv2.mereka.io/ | grep -c ‘undefined_license_key’  # must be 0
curl -s "https://admin.academyv2.mereka.io/api/mfe_config/v1?mfe=admin"       # must return JSON
```

### Rollback

If the new clean image causes a regression (JS boot error, blank page):

```bash
# Pin back to prior tag or :latest
# Edit deploy/k8s/overlays/production/kustomization.yaml
argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal
```

### Background: why we build derivative images

The upstream `enterprise-admin-portal` is built with `ENABLE_NEW_RELIC=true` (Open edX CI default).
This injects New Relic browser agent with `undefined_license_key` placeholders at webpack build time.
We do not have a New Relic license, so the placeholder keys caused unnecessary script noise.

The `infrastructure/docker/enterprise-mfe-clean/` Dockerfiles extend the upstream images and remove
the NREUM `<script>` block once at build time via `strip-nreum.sh`. See also:
`docs/archive/evidence/operations/evidence/69qz-enterprise-mfe-clean-build.md`
