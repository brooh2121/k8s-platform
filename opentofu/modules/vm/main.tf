resource "multipass_instance" "this" {
  name   = var.name
  image  = var.image
  cpus   = var.cpus
  memory = var.memory
  disk   = var.disk

  cloud_init = var.cloud_init != "" ? var.cloud_init : null
}

output "ip" {
  value = multipass_instance.this.ipv4[0]
}