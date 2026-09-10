terraform {
  required_providers {
    multipass = {
      source = "todoroff/multipass"
    }
  }
}

resource "multipass_instance" "this" {
  name   = var.name
  image  = var.image
  cpus   = var.cpus
  memory = var.memory
  disk   = var.disk

  # Добавляем cloud-init с вашим публичным ключом
  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF
}

output "ip" {
  value = multipass_instance.this.ipv4[0]
}