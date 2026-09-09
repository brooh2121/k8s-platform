variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "image" {
  description = "Image to use (e.g., lts, 22.04)"
  type        = string
  default     = "lts"
}

variable "cpus" {
  description = "Number of CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory (e.g., 2G, 4G)"
  type        = string
  default     = "2G"
}

variable "disk" {
  description = "Disk size (e.g., 10G, 20G)"
  type        = string
  default     = "10G"
}

variable "cloud_init" {
  description = "Cloud-init configuration"
  type        = string
  default     = ""
}