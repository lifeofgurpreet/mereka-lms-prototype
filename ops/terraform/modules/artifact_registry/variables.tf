variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "repo_name" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}
