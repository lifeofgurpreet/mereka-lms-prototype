resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repo_name
  format        = "DOCKER"
  description   = "Tutor images for Mereka LMS"
  labels        = var.labels
}

output "repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}

output "repository_name" {
  value = google_artifact_registry_repository.docker.name
}
