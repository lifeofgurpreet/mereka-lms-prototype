variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network" {
  type = string
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
  default = "STANDARD_HA"
}

variable "memory_size_gb" {
  type    = number
  default = 2
}

variable "redis_version" {
  type    = string
  default = "REDIS_6_X"
}

variable "maintenance_day" {
  type    = string
  default = "SUNDAY"
}

variable "maintenance_hour" {
  type    = number
  default = 1
}
