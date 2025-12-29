locals {
  instance_name = var.instance_name != "" ? var.instance_name : "mereka-lms-redis"
}

resource "google_redis_instance" "redis" {
  name           = local.instance_name
  project        = var.project_id
  region         = var.region
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  authorized_network = var.network
  redis_version      = var.redis_version
  display_name       = "Mereka LMS Redis"
  labels             = var.labels

  maintenance_policy {
    weekly_maintenance_window {
      day = var.maintenance_day
      start_time {
        hours   = var.maintenance_hour
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  replica_count   = var.tier == "STANDARD_HA" ? 1 : 0
  transit_encryption_mode = "SERVER_AUTHENTICATION"
}
