# main.tf
terraform {
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "~> 1.7"
    }
  }
}

provider "multipass" {
  # Можно оставить пустым
}

# Мастер-нода
resource "multipass_instance" "master" {
  name   = "k8s-master"
  image  = "lts"
  cpus   = 2
  memory = "2G"
  disk   = "10G"

  # Блок для выполнения скриптов после создания
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from master node'"
    ]
  }
}

# Воркер-нода 1
resource "multipass_instance" "worker1" {
  name   = "k8s-worker1"
  image  = "lts"
  cpus   = 2
  memory = "2G"
  disk   = "10G"
}

# Воркер-нода 2
resource "multipass_instance" "worker2" {
  name   = "k8s-worker2"
  image  = "lts"
  cpus   = 2
  memory = "2G"
  disk   = "10G"
}

# Вывод IP-адресов
output "master_ip" {
  value = multipass_instance.master.ipv4
}

output "worker_ips" {
  value = [
    multipass_instance.worker1.ipv4,
    multipass_instance.worker2.ipv4
  ]
}