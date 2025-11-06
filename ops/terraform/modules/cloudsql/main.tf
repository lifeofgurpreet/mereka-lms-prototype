locals {
  instance_name = var.instance_name != "" ? var.instance_name : "mereka-lms-mysql"
}

# Allocate a private service connection range for Cloud SQL
resource "google_compute_global_address" "private_service_connect" {
  name          = "${local.instance_name}-psc"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect.name]
}

resource "google_sql_database_instance" "mysql" {
  name             = local.instance_name
  project          = var.project_id
  region           = var.region
  database_version = "MYSQL_8_0"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }
    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = var.backup_start_time
      transaction_log_retention_days = 7
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
    }
    disk_type    = "PD_SSD"
    disk_size    = var.disk_size_gb
    disk_autoresize = true
    user_labels  = var.labels
  }

  deletion_protection = var.deletion_protection
}

resource "google_sql_user" "admin" {
  name     = var.root_username
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
  password = var.root_password
}
