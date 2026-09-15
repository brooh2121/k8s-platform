variable "master_ip" {
  description = "IP address of the master node (for workers)"
  type        = string
  default     = ""
}

variable "install_script_path" {
  description = "Absolute path to install-k8s-node.sh on the host that runs tofu apply"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Absolute path to SSH private key on the host that runs tofu apply"
  type        = string
}