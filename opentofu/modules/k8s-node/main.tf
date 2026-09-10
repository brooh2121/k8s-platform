# modules/k8s-node/main.tf
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

# Используем null_resource, чтобы выполнить скрипт на удалённой VM
resource "null_resource" "install_k8s" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.vm_ip
    agent       = true
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.root}/../scripts-tofu/install-k8s-node.sh"
    destination = "/tmp/install-k8s-node.sh"
  }
  
  # Копируем приватный ключ (только для воркеров)
  provisioner "file" {
    source      = "~/.ssh/id_rsa_tofu"
    destination = "/home/ubuntu/.ssh/id_rsa_tofu"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-k8s-node.sh",
      "sudo /tmp/install-k8s-node.sh ${var.node_type} ${var.master_ip}"
    ]
  }
}