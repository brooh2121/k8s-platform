# terraform/main.tf

terraform {
  required_providers {
    multipass = {
      source = "todoroff/multipass"
      version = "~> 1.0"
    }
  }
}

provider "multipass" {
  # Базовые настройки (пока оставляем пустым)
}

resource "multipass_instance" "master" {
  name   = "k8s-master"
  image  = "lts"    # Ubuntu 22.04 LTS
  cpus   = 2
  memory = "2G"
  disk   = "10G"
  
  # Опционально: можно добавить cloud-init для первоначальной настройки
  # cloud_init = file("cloud-init.yaml")
}