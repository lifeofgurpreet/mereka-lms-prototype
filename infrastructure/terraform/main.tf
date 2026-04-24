locals {
  dns_zone_name = replace(var.domain_root, ".", "-")
}

module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region
  labels     = var.labels
}

module "artifact_registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  location   = var.region
  repo_name  = "openedx"
  labels     = var.labels
  depends_on = [module.network]
}

module "gke" {
  source = "./modules/gke"
  providers = {
    google-beta = google-beta
  }
  project_id            = var.project_id
  region                = var.region
  network_self_link     = module.network.vpc_self_link
  subnetwork_self_link  = module.network.subnetwork_self_link
  cluster_name          = "mereka-lms"
  pod_ip_range_name     = module.network.pod_secondary_range_name
  service_ip_range_name = module.network.service_secondary_range_name
  labels                = var.labels
  depends_on            = [module.artifact_registry]
}

module "cloudsql" {
  source        = "./modules/cloudsql"
  project_id    = var.project_id
  region        = var.region
  network       = module.network.vpc_self_link
  labels        = var.labels
  tier          = var.cloudsql_tier
  disk_size_gb  = var.cloudsql_disk_size_gb
  root_username = var.cloudsql_root_username
  root_password = var.cloudsql_root_password
}

module "memorystore" {
  source         = "./modules/memorystore"
  project_id     = var.project_id
  region         = var.region
  network        = module.network.vpc_self_link
  labels         = var.labels
  memory_size_gb = var.redis_memory_size_gb
}

module "storage" {
  source      = "./modules/storage"
  project_id  = var.project_id
  location    = var.region
  domain_root = var.domain_root
  labels      = var.labels
}

module "secret_manager" {
  source     = "./modules/secret_manager"
  project_id = var.project_id
  secrets    = var.secrets
}
