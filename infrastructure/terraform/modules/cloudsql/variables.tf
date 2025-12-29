variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network" {
  type        = string
  description = "Self link to the VPC for private service access"
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "instance_name" {
  type    = string
  default = ""
}

variable "tier" {
  type    = string
  default = "db-custom-2-7680" # 2 vCPU, 7.5 GB RAM
}

variable "high_availability" {
  type    = bool
  default = true
}

variable "disk_size_gb" {
  type    = number
  default = 100
}

variable "maintenance_day" {
  type    = number
  default = 7 # Sunday
}

variable "maintenance_hour" {
  type    = number
  default = 22 # 10pm UTC
}

variable "backup_start_time" {
  type    = string
  default = "03:00"
}

variable "root_username" {
  type    = string
  default = "root"
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}
