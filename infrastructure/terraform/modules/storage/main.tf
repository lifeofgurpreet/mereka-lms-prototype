locals {
  base_name = replace(var.domain_root, ".", "-")
}

resource "google_storage_bucket" "content" {
  name                        = "${local.base_name}-content"
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }
  labels = merge(var.labels, { purpose = "content" })
}

resource "google_storage_bucket" "backup" {
  name                        = "${local.base_name}-backup"
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
  labels = merge(var.labels, { purpose = "backup" })
}
