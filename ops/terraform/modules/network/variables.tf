variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "subnet_cidr" {
  type        = string
  description = "Primary subnet CIDR for workloads"
  default     = "10.20.0.0/20"
}

variable "pod_cidr" {
  type        = string
  description = "Secondary range for GKE pods"
  default     = "10.24.0.0/14"
}

variable "service_cidr" {
  type        = string
  description = "Secondary range for GKE services"
  default     = "10.28.0.0/20"
}

variable "enable_cloud_nat" {
  type        = bool
  description = "Whether to provision Cloud NAT for outbound internet access"
  default     = true
}
