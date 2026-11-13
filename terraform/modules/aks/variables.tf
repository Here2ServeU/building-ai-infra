variable "cluster_name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "node_subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "app_node_vm_size" {
  type    = string
  default = "Standard_D8s_v5"
}

variable "app_node_min" {
  type    = number
  default = 3
}

variable "app_node_max" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "spot_enabled" {
  type        = bool
  description = "Create the Spot node pool for retryable batch work."
  default     = false
}

variable "spot_node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "spot_node_max" {
  type    = number
  default = 5
}

variable "gpu_enabled" {
  type        = bool
  description = "Create the GPU node pool (min 0, tainted nvidia.com/gpu). Set a budget and request 'Standard NCASv3_T4 Family vCPUs' quota first."
  default     = false
}

variable "gpu_node_vm_size" {
  type        = string
  description = "Standard_NC4as_T4_v3 = 1x NVIDIA T4, needs 4 vCPUs of NCASv3_T4 quota. Not every region offers it."
  default     = "Standard_NC4as_T4_v3"
}

variable "gpu_node_max" {
  type    = number
  default = 2
}
