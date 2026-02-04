# Deployment Runbook – Mereka LMS (academyv2.mereka.io)
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-10-30_

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
2. Implement each module under `modules/` (included in repo):
   - `network`: VPC + subnets + secondary ranges for Autopilot.
   - `gke`: Autopilot cluster (Workload Identity, release channel regular).
   - `cloudsql`: MySQL 8 instance + private service access.
   - `memorystore`: Redis standard tier.
   - `artifact_registry`: regional Docker repo `asia-southeast1/openedx`.
   - `storage`: buckets for uploads (`lms-content`), blockstore (`lms-blockstore`), backups (`lms-backup`).
   - `secret_manager`: placeholder secrets (Django key, JWT private key, DB creds, SMTP creds).
3. `terraform init`, `terraform plan`, `terraform apply` once modules are filled.
4. Record outputs (cluster endpoint, SQL connection string, Redis host, bucket names, secret IDs).
   ```bash
   terraform output
   ```
   Current production values (bucket names are legacy):
   - `cloudsql_connection_name = mereka-lms:asia-southeast1:mereka-lms-mysql`
   - `cloudsql_private_ip = 10.97.0.2`
   - `redis_host = 10.150.102.108`
   - `content_bucket = staging-academy-mereka-io-content` (legacy name)
   - `backup_bucket = staging-academy-mereka-io-backup` (legacy name)

## 3. Tutor configuration

1. Copy `infrastructure/tutor/config.example.yml` to `infrastructure/tutor/config.prod.yml` and adjust (use values from `docs/SECRETS_SNAPSHOT.md` for bootstrap):
   - `LMS_HOST`: `academyv2.mereka.io`
   - `CMS_HOST`: `studio.academyv2.mereka.io`
   - `MFE_HOST`: `apps.academyv2.mereka.io`
   - `MFE_DOCKER_IMAGE`: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:nightly` (post-build)
   - `ECOMMERCE_DOCKER_IMAGE`: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-ecommerce:12.0.4`
   - `ECOMMERCE_WORKER_DOCKER_IMAGE`: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-ecommerce-worker:12.0.4`
   - `XQUEUE_DOCKER_IMAGE`: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-xqueue:12.1.0`
   - `MONGODB_URI`: Atlas connection string (leave blank while using the in-cluster StatefulSet).
   - Configure external service endpoints (Cloud SQL host, Memorystore host/port, GCS buckets).
   - For additional LMS domains (microsites), see `docs/MULTISITE.md` and re-run `./infrastructure/tutor/apply-patches.sh` so Caddy/Nginx/Django trust the new hostnames.
2. Store sensitive values in Secret Manager and inject at runtime via Tutor environment overrides (e.g. `tutor config save --set MYSQL_HOST=...`).
3. Prepare Kubernetes overrides, e.g. `tutor config save --set K8S_NAMESPACE=mereka-lms` and `tutor config save --set REGISTRY_URL=asia-southeast1-docker.pkg.dev/mereka-lms/openedx`.

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
   tutor images push all --repository asia-southeast1-docker.pkg.dev/mereka-lms/openedx
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
4. MongoDB (production): use Atlas (no in-cluster StatefulSet)
   ```bash
   tutor k8s exec -- kubectl apply -f k8s/addons/mongodb-statefulset.yaml
   ```
   (See `docs/MONGODB_ATLAS.md` for migrating this data set to Atlas via `scripts/infra/mongodb-to-atlas.sh` and the new `MONGODB_URI` setting.)
   - Ready to cut over? Run `ATLAS_URI=... ./scripts/infra/mongodb-atlas-cutover.sh` to dump the StatefulSet to Atlas, update Tutor config, restart `forum`, and (optionally) delete the StatefulSet/PVC once the Atlas connection is verified.
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
- Configure backups (details in this section):
1. Grant the Cloud SQL service account access to the backup bucket  
   `gsutil iam ch serviceAccount:p355915112439-ora2um@gcp-sa-cloud-sql.iam.gserviceaccount.com:roles/storage.objectAdmin gs://staging-academy-mereka-io-backup` (legacy bucket name)
2. Run ad-hoc exports with `./scripts/infra/backup-db.sh` (set `DATABASES='openedx discovery'` to limit scope).  Output is stored under `gs://staging-academy-mereka-io-backup/sql/<timestamp>/` (legacy bucket name).
3. To balance cost, schedule **10 exports per month** (roughly every 3 days). The repo includes `.github/workflows/cloud-sql-backup.yml`, which runs on the cron `0 18 */3 * *` (UTC). Create a dedicated service account (roles: `roles/cloudsql.admin` + `roles/storage.objectAdmin`), download its JSON key, and store it as the GitHub secret `GCP_SA_KEY`. The workflow invokes `./scripts/infra/backup-db.sh` using those credentials. (Service account `cloud-sql-backup@mereka-lms.iam.gserviceaccount.com` already exists; its JSON payload is tracked in `docs/SECRETS_SNAPSHOT.md` until we rotate it.)
   - Serverless exports only incur storage-and-egress costs: ~$0.10/GB written to GCS plus Cloud Storage at $0.026/GB-month in `asia-southeast1`. At the current data size (<1 GB per database) each run costs only a few cents.
4. Apply the lifecycle policy under `infrastructure/storage/backup-lifecycle.json` so objects in `sql/` older than 60 days are deleted automatically (`gsutil lifecycle set infrastructure/storage/backup-lifecycle.json gs://staging-academy-mereka-io-backup`) (legacy bucket name).
- Store long-lived secrets in Google Secret Manager so CI and operators pull values without editing `tutor_env/config.yml` directly. Minimum list: Django secret key, JWT private key, LMS superuser password, SMTP password, and the soon-to-exist `mongodb-atlas-uri`. Add new values with `gcloud secrets versions add NAME --data-file=-` and reference them via `tutor config save --set KEY="$(gcloud secrets versions access ...)"`.
- Apply the Mereka branding pack after each upgrade:
  ```bash
  ./scripts/branding/sync-brand-assets.sh
  tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
  ./infrastructure/tutor/apply-patches.sh
  tutor images build openedx && tutor images build mfe
  ```
  The patch step copies the SCSS/fonts into the Indigo MFE build so all micro-frontends share the same palette.
- Hook monitoring dashboards/alerts (see `docs/MONITORING.md` + JSON templates in `infrastructure/monitoring/`).
- Review the DR runbook and backup cadence in `docs/operations/DISASTER_RECOVERY.md`.
- Enforce cost guardrails via Terraform budgets. Populate `billing_account_id`, `monthly_budget_myr`, and `budget_thresholds` in `infrastructure/terraform/terraform.tfvars`, then apply:
  ```bash
  cd infrastructure/terraform
  terraform init
  GOOGLE_CLOUD_QUOTA_PROJECT=mereka-lms terraform apply -target=google_billing_budget.mereka_monthly
  ```
  This provisions a Cloud Billing budget with alert thresholds (default 62.5% and 100%). Add notification channel resource names to `budget_monitoring_channels` if you want alerts to hit `techadmin@biji-biji.com` via Cloud Monitoring.

## 7. GitHub integration

- Repo: `https://github.com/Biji-Biji-Initiative/mereka-lms` (remote `origin` already configured locally).
- Backups: `.github/workflows/cloud-sql-backup.yml` runs every three days; it authenticates via secret `GCP_SA_KEY` that contains the `cloud-sql-backup@mereka-lms.iam.gserviceaccount.com` JSON key.
- Next pipeline work: add workflows for (a) Tutor image build/push + smoke tests and (b) Terraform plan/apply with manual approvals. Store any additional credentials (Artifact Registry robot, MongoDB Atlas API, etc.) as repo secrets instead of committing them here.

## 8. Cutover checklist

- Domains pointing to the GCLB IP.
- TLS certificates valid.
- Admin login verified.
- Email (SMTP) smoke test.
- Backup job success recorded.

> Track outstanding tasks/issues in the repo’s issue tracker to keep the deployment plan auditable.
