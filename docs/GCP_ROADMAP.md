# GCP Deployment Roadmap

The goal is to migrate the nightly Open edX stack managed by Tutor to Google Cloud Platform while keeping the local sandbox as the source of truth.

## Project scaffolding

1. Create a dedicated project (e.g. `mereka-openedx-nightly`) and link billing.
2. Enable required APIs:
   - `compute.googleapis.com`
   - `sqladmin.googleapis.com`
   - `container.googleapis.com` (if we use GKE)
   - `artifactregistry.googleapis.com`
   - `iam.googleapis.com`
   - `dns.googleapis.com`
3. Set up IAM groups:
   - `openedx-admins` (Owner + Billing admin)
   - `openedx-devops` (Compute Admin, Kubernetes Admin, Artifact Registry admin)
   - `openedx-readonly` (Viewer, Log Viewer)

## Runtime options

### Option A – Single VM (pilot)

- Compute Engine e2-standard-8 (or higher) with 200 GB SSD.
- Install Docker + docker compose; clone this repo.
- Attach persistent disks for MySQL and MongoDB data directories and mount to `/var/lib/mysql` and `/var/lib/mongodb`.
- Use Cloud DNS + Let's Encrypt via `tutor local https set` on the host.
- Backups: Cloud Storage bucket for nightly `tutor local do backup-db` artifacts.

### Option B – GKE Autopilot (preferred for scale)

- Autopilot = Google manages node provisioning, upgrades, OS patching, and security hardening. You only declare pod resource requests and pay for what the workloads reserve.
- Create an Autopilot cluster in `asia-southeast1` (close to our learners).
- Use Artifact Registry (`gcr.io`) to store Tutor-built images (`tutor images build all && tutor images push all`).
- Externalize services:
  - **Cloud SQL (MySQL 8)** – managed backups/patching; slightly higher latency than self-managed but easier ops.
  - **MongoDB Atlas (M10+)** – managed upgrades/backups; alternative is self-managed Mongo on GCE if we want to avoid SaaS.
  - **Memorystore (Redis standard tier)** – handles failover and updates; fallback is Redis on GKE with Persistent Disk for more customization.
  - **Google Cloud Storage** buckets for blockstore, static assets, and DB backups (Tutor uses S3-compatible env vars).
- TLS: Cert-Manager with DNS-01 via Cloud DNS, or Cloud Load Balancing with managed certs.
- Storage classes: use Filestore CSI or GCP PD-CSI for StatefulSets.

## Automation outline

- **Config repo**: keep sanitized Tutor config in `ops/tutor/config.prod.yml` (no secrets). Load real values via CI before deployment.
- **Secrets**: temporary bootstrap values live in `docs/SECRETS_SNAPSHOT.md`; migrate them to Secret Manager and rotate immediately after bring-up.
- **Terraform**: modules for VPC, subnets, Cloud SQL, Memorystore, Artifact Registry, GKE cluster, Cloud DNS, and service accounts.
- **CI/CD**: GitHub Actions pipeline steps
  1. `pip install -r requirements-dev.txt` (Tutor CLI + plugins).
  2. `tutor images build all --no-cache`.
  3. `tutor images push all` to Artifact Registry.
  4. `tutor k8s quickstart` followed by `kubectl apply -k k8s/overlays/prod` (rendered manifests).

## Secrets management

- Use Secret Manager to store:
  - Django secret key
  - JWT RSA private key
  - LMS/CMS OAuth credentials
  - Database passwords
  - SMTP credentials
- Mount secrets into Tutor via environment overrides (e.g. `tutor config save --set` or Kubernetes Secret manifests).

## Observability

- Enable Cloud Logging + Cloud Monitoring; use Ops Agent or sidecar to forward container logs.
- Deploy Prometheus/Grafana stack (`tutor-contrib-prometheus` once updated) or integrate with Google Managed Service for Prometheus.
- Configure alerts for
  - HTTP 5xx from LMS/Studio ingress
  - Celery worker queue depth
  - Database CPU/memory thresholds

## Cost controls

- Add Cloud Billing budgets through Terraform (`ops/terraform/budgets.tf`) so RM400/month is enforced with alerts at 62.5% and 100% of spend (`google_billing_budget.mereka_monthly`).
- **Status:** Applied on 2025-11-08 (notifications: techadmin@biji-biji.com, team@mereka.io). Re-run Terraform with `GOOGLE_CLOUD_QUOTA_PROJECT=mereka-lms` after edits.
- Publish billing export to BigQuery once budgets are active to trend per-service costs and feed future dashboards.

## Managed service choices

| Component | Managed option | Pros | Cons | Recommendation |
|-----------|----------------|------|------|----------------|
| MySQL | Cloud SQL (MySQL 8) | Automated backups, HA, maintenance windows, built-in IAM auth | Higher cost, connection limits, cross-region latency | **Adopt** Cloud SQL with private IP |
| MongoDB | MongoDB Atlas | Automated patching, backups, monitoring | Separate SaaS billing, VPC peering required, adds Atlas control plane | **Plan for production**; staging uses in-cluster StatefulSet |
| Redis | Memorystore (Standard) | Fully managed failover, metrics, maintenance | No custom modules, size-based pricing | **Adopt** Standard tier (~1–5 GB) |
| Object storage | Google Cloud Storage | Durable, lifecycle policies, easy TLS | Multi-region costs higher | **Adopt** regional (asia-southeast1) buckets |
| Secrets | Secret Manager | Versioned secrets, IAM-based access | API quotas (rarely an issue) | **Adopt** for all credentials |

> For pilot / staging, we can temporarily run MongoDB inside GKE using StatefulSets, but production should move to Atlas or a managed equivalent for reliability.

## Next steps

1. Draft Terraform skeleton under `ops/terraform/` (TODO) to define project baseline.
2. Produce sanitized `config.prod.example.yml` with non-secret overrides (domains, plugin list, release channel).
3. Write GitHub Action workflow for image build/push (blocked until repo is connected to GitHub).
