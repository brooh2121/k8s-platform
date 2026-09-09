# opentofu/main.tf

terraform {
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "~> 1.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

module "master_vm" {
  source = "./modules/vm"
  name   = "k8s-master"
  cpus   = 2
  memory = "2G"
  disk   = "10G"
}

module "worker1_vm" {
  source = "./modules/vm"
  name   = "k8s-worker1"
  cpus   = 2
  memory = "2G"
  disk   = "10G"
}

module "worker2_vm" {
  source = "./modules/vm"
  name   = "k8s-worker2"
  cpus   = 2
  memory = "2G"
  disk   = "10G"
}

# Установка Kubernetes на мастер
module "k8s_master" {
  source     = "./modules/k8s-node"
  vm_ip      = module.master_vm.ip
  node_type  = "master"
  depends_on = [module.master_vm]   # Ждём, пока VM создастся
}

# Установка Kubernetes на воркеры
module "k8s_worker1" {
  source     = "./modules/k8s-node"
  vm_ip      = module.worker1_vm.ip
  node_type  = "worker"
  depends_on = [module.worker1_vm, module.k8s_master]
}

module "k8s_worker2" {
  source     = "./modules/k8s-node"
  vm_ip      = module.worker2_vm.ip
  node_type  = "worker"
  depends_on = [module.worker2_vm, module.k8s_master]
}