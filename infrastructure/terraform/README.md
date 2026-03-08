# Terraform Infrastructure

This directory contains Infrastructure-as-Code for the Mereka LMS platform on GCP.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GCP Project (mereka-lms)                 │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GKE Autopilot│  │  Cloud SQL  │  │  Memorystore Redis  │  │
│  │ (Kubernetes) │  │  (MySQL 8)  │  │      (Cache)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Artifact   │  │    GCS      │  │   Secret Manager    │  │
│  │  Registry   │  │  (Storage)  │  │     (Secrets)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    VPC Network                         │ │
│  │  • Subnetwork with secondary ranges for pods/services  │ │
│  │  • Private Service Access for Cloud SQL                │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `network` | VPC, subnets, firewall rules, private service access |
| `gke` | GKE Autopilot cluster |
| `cloudsql` | Cloud SQL MySQL 8 instance |
| `memorystore` | Redis for caching |
| `artifact_registry` | Docker image repository |
| `storage` | GCS buckets for assets, backups |
| `secret_manager` | Secrets storage |

## Prerequisites

1. **GCP Project** - Project must exist with billing enabled
2. **APIs Enabled**:
   ```bash
   gcloud services enable \
     compute.googleapis.com \
     container.googleapis.com \
     sqladmin.googleapis.com \
     redis.googleapis.com \
     artifactregistry.googleapis.com \
     secretmanager.googleapis.com \
     servicenetworking.googleapis.com \
     --project=mereka-lms
   ```
3. **Terraform >= 1.5.0** - `terraform version`
4. **GCP Authentication**:
   ```bash
   gcloud auth application-default login
   # OR use a service account
   export GOOGLE_CREDENTIALS=/path/to/service-account-key.json
   ```

## Quick Start

### 1. Create State Bucket (First Time Only)

```bash
gsutil mb -p mereka-lms -l asia-southeast1 gs://mereka-lms-terraform-state
gsutil versioning set on gs://mereka-lms-terraform-state
```

### 2. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

### 3. Select Environment

```bash
# Production
terraform workspace select production || terraform workspace new production
```

### 4. Plan & Apply

```bash
# Set sensitive variables
export TF_VAR_cloudsql_root_password="$(openssl rand -base64 32)"

# Production (requires separate project)
terraform plan -var-file=environments/production.tfvars -out=tfplan
terraform apply tfplan
```

## Environment Files

| File | Purpose |
|------|---------|
| `environments/staging.tfvars` | Legacy staging (reference only) |
| `environments/production.tfvars` | Production environment (mereka-lms-prod project) |
| `terraform.tfvars.example` | Example with all variables |

## Multi-Environment Strategy

### Option A: Terraform Workspaces (Recommended)

```bash
# Same project, different state
terraform workspace new production
terraform apply -var-file=environments/production.tfvars
```

### Option B: Separate Projects (Stronger Isolation)

For production, create a separate GCP project:

```bash
gcloud projects create mereka-lms-prod --organization=YOUR_ORG_ID
gcloud billing projects link mereka-lms-prod --billing-account=01A879-A82798-7962E2
```

Then use `project_id = "mereka-lms-prod"` in production.tfvars.

## Outputs

After applying, these outputs are available:

```hcl
output "gke_cluster_name"      { ... }
output "gke_cluster_endpoint"  { ... }
output "cloudsql_connection"   { ... }
output "redis_host"            { ... }
output "artifact_registry_url" { ... }
```

Access with: `terraform output -json`

## Cost Estimates

| Environment | Monthly (MYR) | Notes |
|-------------|---------------|-------|
| Staging | ~RM400 | 2 vCPU Cloud SQL, 2GB Redis, Autopilot pods |
| Production | ~RM1500 | 4 vCPU Cloud SQL, 4GB Redis, more replicas |

Budget alerts configured at 62.5% and 100% of threshold.

## Security Notes

1. **Never commit secrets** - Use `TF_VAR_*` environment variables
2. **State is encrypted** - GCS backend with versioning
3. **Audit logs** - Cloud Audit Logs enabled by default
4. **Private networking** - Cloud SQL uses private IP via VPC

## Troubleshooting

### "Error 403: Access Denied"
```bash
gcloud auth application-default login
# Or check service account permissions
```

### "Resource already exists"
```bash
# Import existing resources
terraform import module.gke.google_container_cluster.autopilot projects/mereka-lms/locations/asia-southeast1/clusters/mereka-lms
```

### "State locked"
```bash
terraform force-unlock LOCK_ID
```

## Related Documentation

- [GCP Roadmap](../../docs/operations/GCP_ROADMAP.md)
- [CI/CD Setup](../../docs/reference/operations/CI_CD_SETUP.md)
- [Disaster Recovery](../../docs/operations/DR_TEST_RESULTS.md)
