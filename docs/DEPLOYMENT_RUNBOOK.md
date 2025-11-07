# Deployment Runbook – Mereka LMS (staging.academy.mereka.io)

This runbook captures the steps to roll out the nightly Open edX stack on Google Cloud in the new `mereka-lms` project.

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

1. `cd ops/terraform` and create `terraform.tfvars`:
   ```hcl
   project_id  = "mereka-lms"
   domain_root = "staging.academy.mereka.io"
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
   Current staging values:
   - `cloudsql_connection_name = mereka-lms:asia-southeast1:mereka-lms-mysql`
   - `cloudsql_private_ip = 10.97.0.2`
   - `redis_host = 10.150.102.108`
   - `content_bucket = staging-academy-mereka-io-content`
   - `backup_bucket = staging-academy-mereka-io-backup`

## 3. Tutor configuration

1. Copy `ops/tutor/config.example.yml` to `ops/tutor/config.prod.yml` and adjust (use values from `docs/SECRETS_SNAPSHOT.md` for bootstrap):
   - `LMS_HOST`: `staging.academy.mereka.io`
   - `CMS_HOST`: `studio.staging.academy.mereka.io`
   - `MFE_DOCKER_IMAGE`: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:nightly` (post-build)
   - Configure external service endpoints (Cloud SQL host, Atlas URI, Memorystore host/port, GCS buckets).
2. Store sensitive values in Secret Manager and inject at runtime via Tutor environment overrides (e.g. `tutor config save --set MYSQL_HOST=...`).
3. Prepare Kubernetes overrides, e.g. `tutor config save --set K8S_NAMESPACE=mereka-lms` and `tutor config save --set REGISTRY_URL=asia-southeast1-docker.pkg.dev/mereka-lms/openedx`.

## 4. Build & push images

1. Authenticate Docker with Artifact Registry:
   ```bash
   gcloud auth configure-docker asia-southeast1-docker.pkg.dev
   ```
2. Build Tutor images:
   ```bash
   source ops/tutor-env.sh
   ./ops/tutor/apply-patches.sh
   tutor images build all
   tutor images push all --repository asia-southeast1-docker.pkg.dev/mereka-lms/openedx
   ```
   (Ensure `MFE_DOCKER_IMAGE` is updated before pushing.)

## 5. Deploy to GKE Autopilot

1. Generate Kubernetes config:
   ```bash
   source ops/tutor-env.sh
   tutor k8s quickstart --non-interactive
   ```
2. Apply secrets via Secret Manager CSI or Kubernetes secrets populated from `gcloud secrets versions access`.
3. Deploy resources:
   ```bash
   tutor k8s init
   tutor k8s start
   ```
4. MongoDB (staging): deploy bundled StatefulSet
   ```bash
   tutor k8s exec -- kubectl apply -f k8s/addons/mongodb-statefulset.yaml
   ```
   (We’ll migrate to Atlas for production later.)
5. Verify pods: `kubectl get pods -n mereka-lms`.
6. Provision HTTPS certificates (either Tutor Let’s Encrypt or Cloud Load Balancer + managed cert). Update DNS records in Cloud DNS zone `staging-academy-mereka-io`.

## 6. Post-deploy tasks

- Create superuser:
  ```bash
  tutor k8s do createuser gurpreet@biji-biji.com \
    gurpreet@biji-biji.com --staff --superuser --password-from-env SUPERUSER_PASSWORD
  ```
  (Set the password via Secret Manager or prompt; never commit credentials.)
- Smoke test LMS, Studio, Discovery, MFEs (`./tools/smoke-test.sh` covers the public endpoints).
- Configure backups (details in this section):
1. Grant the Cloud SQL service account access to the backup bucket  
   `gsutil iam ch serviceAccount:p355915112439-ora2um@gcp-sa-cloud-sql.iam.gserviceaccount.com:roles/storage.objectAdmin gs://staging-academy-mereka-io-backup`
2. Run ad-hoc exports with `./tools/backup-db.sh` (set `DATABASES='openedx discovery'` to limit scope).  Output is stored under `gs://staging-academy-mereka-io-backup/sql/<timestamp>/`.
3. To balance cost, schedule **10 exports per month** (roughly every 3 days). With Cloud Scheduler, set the cron expression `0 2 */3 * *` (UTC) pointing to a Cloud Run job/VM that executes the same `gcloud sql export sql` commands; see comments inside `tools/backup-db.sh` for the exact set of databases.
   - Serverless exports only incur storage-and-egress costs: ~$0.10/GB written to GCS plus Cloud Storage at $0.026/GB-month in `asia-southeast1`. The current databases are small (<1 GB each), so a nightly export set costs only cents per day.
- Hook monitoring dashboards/alerts (see `docs/MONITORING.md` + JSON templates in `ops/monitoring/`).

## 7. GitHub integration

- Create repo `mereka-lms` in the organization.
- Add GitHub Actions workflow (TODO) to run Terraform plan (with manual approval), build/push Tutor images, and trigger `tutor k8s upgrade` jobs.
- Store Artifact Registry and GCP service account credentials in GitHub secrets.

## 8. Cutover checklist

- Domains pointing to the GCLB IP.
- TLS certificates valid.
- Admin login verified.
- Email (SMTP) smoke test.
- Backup job success recorded.

> Track outstanding tasks/issues in the repo’s issue tracker to keep the deployment plan auditable.
