output "network_vpc" {
  description = "Self link of the primary VPC."
  value       = module.network.vpc_self_link
}

output "gke_cluster_name" {
  description = "Name of the Autopilot GKE cluster."
  value       = module.gke.cluster_name
}

output "artifact_repo" {
  description = "Artifact Registry repository for Tutor images."
  value       = module.artifact_registry.repository_name
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection string."
  value       = module.cloudsql.instance_connection_name
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address."
  value       = module.cloudsql.instance_private_ip
}

output "redis_host" {
  description = "Memorystore Redis primary host."
  value       = module.memorystore.primary_host
}

output "redis_port" {
  description = "Memorystore Redis port."
  value       = module.memorystore.primary_port
}

output "content_bucket" {
  description = "Bucket for LMS uploads."
  value       = module.storage.content_bucket
}

output "backup_bucket" {
  description = "Bucket for backups."
  value       = module.storage.backup_bucket
}
