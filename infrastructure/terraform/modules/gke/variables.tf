variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "subnetwork_self_link" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "pod_ip_range_name" {
  type = string
}

variable "service_ip_range_name" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "maintenance_start" {
  type    = string
  default = "2025-01-01T22:00:00Z"
}

variable "maintenance_end" {
  type    = string
  default = "2025-01-02T02:00:00Z"
}

variable "maintenance_recurrence" {
  type    = string
  default = "FREQ=WEEKLY;BYDAY=SU"
}

variable "deletion_protection" {
  type    = bool
  default = true
}
