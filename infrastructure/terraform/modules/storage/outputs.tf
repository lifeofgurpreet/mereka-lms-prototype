output "content_bucket" {
  value = google_storage_bucket.content.name
}

output "backup_bucket" {
  value = google_storage_bucket.backup.name
}
