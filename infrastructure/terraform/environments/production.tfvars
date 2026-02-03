# Production Environment Configuration
# Usage: terraform apply -var-file=environments/production.tfvars
#
# IMPORTANT: Production requires a separate GCP project for isolation
# Create project: gcloud projects create mereka-lms-prod --organization=XXXX

project_id  = "mereka-lms-prod"  # Separate project for production
region      = "asia-southeast1"
zone        = "asia-southeast1-a"
domain_root = "academyv2.mereka.io"

# Billing - higher budget for production
billing_account_id = "01A879-A82798-7962E2"
monthly_budget_myr = 1500
budget_thresholds  = [0.5, 0.75, 0.9, 1.0]

# Database - larger for production
cloudsql_tier         = "db-custom-4-15360"  # 4 vCPU, 15GB RAM
cloudsql_disk_size_gb = 200
cloudsql_root_username = "root"
# cloudsql_root_password = Set via TF_VAR_cloudsql_root_password env var

# Redis - larger for production
redis_memory_size_gb = 4

# Labels
labels = {
  managed-by  = "terraform"
  project     = "mereka-lms"
  environment = "production"
}

# Production secrets (seed these after initial deployment)
# secrets = [
#   { name = "lms-django-secret" },
#   { name = "lms-oauth-client-secret" },
#   { name = "ses-smtp-password" },
# ]
