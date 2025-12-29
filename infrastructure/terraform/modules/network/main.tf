locals {
  base_name = replace(var.project_id, "_", "-")
}

resource "google_compute_network" "vpc" {
  name                    = "${local.base_name}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  delete_default_routes_on_create = false
  description             = "Primary VPC for Mereka LMS"
  mtu                     = 1460
}

resource "google_compute_subnetwork" "primary" {
  name          = "${local.base_name}-primary"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "${local.base_name}-pods"
    ip_cidr_range = var.pod_cidr
  }

  secondary_ip_range {
    range_name    = "${local.base_name}-services"
    ip_cidr_range = var.service_cidr
  }

  private_ip_google_access = true
  description              = "Primary subnetwork for Mereka LMS workloads"
}

resource "google_compute_router" "nat" {
  name    = "${local.base_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${local.base_name}-nat-ip"
  project = var.project_id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "${local.base_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.nat.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat[*].self_link
  min_ports_per_vm                   = 128
  udp_idle_timeout_sec               = 30
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ALL"
  }
}

output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnetwork_self_link" {
  value = google_compute_subnetwork.primary.self_link
}

output "pod_secondary_range_name" {
  value = google_compute_subnetwork.primary.secondary_ip_range[0].range_name
}

output "service_secondary_range_name" {
  value = google_compute_subnetwork.primary.secondary_ip_range[1].range_name
}
