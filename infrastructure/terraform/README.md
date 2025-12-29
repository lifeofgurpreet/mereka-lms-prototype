# Terraform Scaffolding (stub)

This directory will house the Infrastructure-as-Code for the `mereka-lms` GCP project. The current layout is scaffolding only:

- `providers.tf` pins the Google providers (stable + beta) and references `var.project_id`.
- `main.tf` wires together modules for networking, GKE Autopilot, Cloud SQL, Memorystore, Artifact Registry, Storage, and Secret Manager.
- `modules/` contains stub module directories – implement each before running `terraform plan`.

## Usage

1. Copy `terraform.tfvars.example` (to be added) and populate:
   ```hcl
   project_id  = "mereka-lms"
   domain_root = "staging.academy.mereka.io"
   ```
2. Run `gcloud auth application-default login` (or use a service account) before planning.
3. Execute `terraform init`, then fill in module implementations.

> **Note:** No resources will be created until the stub modules are populated with real Google Cloud resources.
