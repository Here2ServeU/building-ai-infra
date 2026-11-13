variable "project_id" { type = string }
variable "cluster_name" { type = string }
variable "region" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }

variable "master_ipv4_cidr_block" {
  type    = string
  default = "172.16.0.0/28"
}

variable "private_endpoint" {
  type    = bool
  default = false
}

variable "master_authorized_cidrs" {
  type    = list(object({ name = string, cidr = string }))
  default = []
}

variable "app_node_machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "app_node_min" {
  type    = number
  default = 3
}

variable "app_node_max" {
  type    = number
  default = 20
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "gpu_enabled" {
  type        = bool
  description = "Create the GPU node pool (min 0, tainted nvidia.com/gpu, Google-managed driver)."
  default     = false
}

variable "gpu_node_machine_type" {
  type    = string
  default = "n1-standard-4"
}

variable "gpu_accelerator_type" {
  type    = string
  default = "nvidia-tesla-t4"
}

variable "gpu_node_zones" {
  type        = list(string)
  description = "Zones that offer the accelerator. Empty = all zones in the region (may fail if a zone lacks T4s)."
  default     = []
}

variable "gpu_node_max" {
  type    = number
  default = 2
}
