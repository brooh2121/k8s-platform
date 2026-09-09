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

  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from master node'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa_tofu")
      host        = self.ipv4[0]
      timeout     = "2m"
    }
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