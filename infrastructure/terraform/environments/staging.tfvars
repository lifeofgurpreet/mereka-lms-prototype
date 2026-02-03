# Staging Environment Configuration
# Usage: terraform apply -var-file=environments/staging.tfvars

project_id  = "mereka-lms"
region      = "asia-southeast1"
zone        = "asia-southeast1-a"
domain_root = "staging.academy.mereka.io"

# Billing (use actual billing account ID)
billing_account_id = "01A879-A82798-7962E2"
monthly_budget_myr = 400
budget_thresholds  = [0.625, 1.0]

# Database - smaller for staging
cloudsql_tier         = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM
cloudsql_disk_size_gb = 100
cloudsql_root_username = "root"
# cloudsql_root_password = Set via TF_VAR_cloudsql_root_password env var

# Redis - smaller for staging
redis_memory_size_gb = 2

# Labels
labels = {
  managed-by  = "terraform"
  project     = "mereka-lms"
  environment = "staging"
}
