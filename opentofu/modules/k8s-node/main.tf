# modules/k8s-node/main.tf
# Копирует install-k8s-node.sh на VM по SSH и запускает установку Kubernetes.
# Скрипт читается процессом tofu (WSL), поэтому нужен абсолютный путь к Windows-checkout,
# обычно /mnt/e/git_works/k8s-platform/k8s-platform/scripts-tofu/install-k8s-node.sh.

variable "vm_ip" {
  description = "IP address of the VM"
  type        = string
}

variable "node_type" {
  description = "Type of node: master or worker"
  type        = string
  validation {
    condition     = var.node_type == "master" || var.node_type == "worker"
    error_message = "node_type must be either 'master' or 'worker'."
  }
}

resource "null_resource" "install_k8s" {
  triggers = {
    vm_ip      = var.vm_ip
    node_type  = var.node_type
    script_sha = filesha256(var.install_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = var.vm_ip
    agent   = true
    timeout = "10m"
  }

  # content + file() читает скрипт в память tofu. Так надежнее, чем source:
  # source зависит от того, как provisioner резолвит путь (Win vs WSL).
  provisioner "file" {
    content     = file(var.install_script_path)
    destination = "/tmp/install-k8s-node.sh"
  }

  provisioner "file" {
    content     = file(var.ssh_private_key_path)
    destination = "/home/ubuntu/.ssh/id_rsa_tofu"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-k8s-node.sh",
      "chmod +x /tmp/install-k8s-node.sh",
      "chmod 600 /home/ubuntu/.ssh/id_rsa_tofu",
      "sudo /tmp/install-k8s-node.sh ${var.node_type} ${var.master_ip}"
    ]
  }
}
