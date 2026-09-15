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

# Git на Windows, tofu apply в WSL: path.root будет /mnt/<диск>/.../opentofu,
# а не /home/dismas/k8s-platform и не E:\git_works\...
locals {
  install_script_path  = abspath("${path.root}/../scripts-tofu/install-k8s-node.sh")
  ssh_private_key_path = pathexpand("~/.ssh/id_rsa_tofu")
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

resource "null_resource" "master_ready" {
  depends_on = [module.k8s_master]

  provisioner "local-exec" {
    command = "multipass exec k8s-master -- sudo cat /tmp/join-command > ${path.root}/join-command.txt"
  }
}

# Установка Kubernetes на мастер
module "k8s_master" {
  source              = "./modules/k8s-node"
  vm_ip               = module.master_vm.ip
  node_type           = "master"
  install_script_path = local.install_script_path
  ssh_private_key_path = local.ssh_private_key_path
  depends_on          = [module.master_vm]
}

# Установка Kubernetes на воркеры
module "k8s_worker1" {
  source               = "./modules/k8s-node"
  vm_ip                = module.worker1_vm.ip
  node_type            = "worker"
  master_ip            = module.master_vm.ip
  install_script_path  = local.install_script_path
  ssh_private_key_path = local.ssh_private_key_path
  depends_on           = [module.worker1_vm, module.k8s_master]
}

module "k8s_worker2" {
  source               = "./modules/k8s-node"
  vm_ip                = module.worker2_vm.ip
  node_type            = "worker"
  master_ip            = module.master_vm.ip
  install_script_path  = local.install_script_path
  ssh_private_key_path = local.ssh_private_key_path
  depends_on           = [module.worker2_vm, module.k8s_master]
}