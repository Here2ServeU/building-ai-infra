variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the GKE master endpoint."
  type        = list(string)
  default     = []
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "gpu_enabled" {
  type        = bool
  description = "Add the GPU node pool (min 0). Set a budget alert and request GPU quota before enabling."
  default     = false
}
