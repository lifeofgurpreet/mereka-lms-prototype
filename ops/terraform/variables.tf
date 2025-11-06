variable "project_id" {
  type        = string
  description = "GCP project ID (e.g. mereka-lms)."
}

variable "region" {
  type        = string
  description = "Primary GCP region for regional services."
  default     = "asia-southeast1"
}

variable "zone" {
  type        = string
  description = "Default zone for zonal resources when needed."
  default     = "asia-southeast1-a"
}

variable "domain_root" {
  type        = string
  description = "Root domain for platform (e.g. staging.academy.mereka.io)."
}

variable "labels" {
  type        = map(string)
  description = "Common labels to attach to resources."
  default     = {
    managed-by = "terraform"
    project    = "mereka-lms"
  }
}

variable "cloudsql_root_password" {
  type        = string
  description = "Root password for the Cloud SQL MySQL instance. Use Secret Manager or env var when applying."
  sensitive   = true
}

variable "cloudsql_root_username" {
  type        = string
  description = "Root username for Cloud SQL."
  default     = "root"
}

variable "cloudsql_tier" {
  type        = string
  description = "Instance tier (CPU/RAM) for Cloud SQL."
  default     = "db-custom-2-7680"
}

variable "cloudsql_disk_size_gb" {
  type        = number
  description = "Initial disk size for Cloud SQL."
  default     = 100
}

variable "redis_memory_size_gb" {
  type        = number
  description = "Memorystore memory size in GB."
  default     = 2
}

variable "secrets" {
  description = "Optional list of secrets to seed in Secret Manager."
  type = list(object({
    name        = string
    data        = optional(string)
    annotations = optional(map(string))
    labels      = optional(map(string))
  }))
  default = []
}
