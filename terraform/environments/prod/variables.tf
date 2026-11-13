variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "gpu_enabled" {
  type        = bool
  description = "Add the GPU node pool (min 0). Set a budget alert and request GPU quota before enabling."
  default     = false
}

variable "spot_enabled" {
  type        = bool
  description = "Add the Spot node pool for retryable batch work."
  default     = false
}
