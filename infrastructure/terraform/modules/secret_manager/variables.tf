variable "project_id" {
  type = string
}

variable "secrets" {
  description = "List of secrets (map: name, replication, data) to create."
  type = list(object({
    name         = string
    replication  = optional(string, "automatic")
    data         = optional(string)
    annotations  = optional(map(string), {})
    labels       = optional(map(string), {})
  }))
  default = []
}
