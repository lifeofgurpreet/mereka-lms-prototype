output "content_bucket" {
  value = google_storage_bucket.content.name
}

output "backup_bucket" {
  value = google_storage_bucket.backup.name
}

output "blockstore_bucket_name" {
  value       = google_storage_bucket.blockstore.name
  description = "Name of the Blockstore GCS bucket for Content Libraries v2"
}
