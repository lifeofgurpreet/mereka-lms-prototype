locals {
  secrets = { for secret in var.secrets : secret.name => secret }
}

resource "google_secret_manager_secret" "this" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = each.value.name

  replication {
    auto {}
  }

  labels      = try(each.value.labels, {})
  annotations = try(each.value.annotations, {})
}

resource "google_secret_manager_secret_version" "initial" {
  for_each = { for name, secret in local.secrets : name => secret if try(secret.data, null) != null }

  secret      = google_secret_manager_secret.this[each.key].id
  secret_data = each.value.data
}

output "secret_ids" {
  value = { for name, resource in google_secret_manager_secret.this : name => resource.id }
}
