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
  scripts_dir          = abspath("${path.root}/../scripts-tofu")
  install_script_path  = "${local.scripts_dir}/install-k8s-node.sh"
  flannel_script_path  = "${local.scripts_dir}/install-flannel.sh"
  metallb_script_path  = "${local.scripts_dir}/install-metallb.sh"
  ingress_script_path  = "${local.scripts_dir}/install-ingress.sh"
  argocd_script_path   = "${local.scripts_dir}/install-argocd.sh"
  gitops_script_path   = "${local.scripts_dir}/setup-gitops.sh"
  rbac_script_path     = "${local.scripts_dir}/install-rbac.sh"
  rbac_test_script_path = "${local.scripts_dir}/test-rbac.sh"
  rbac_dir             = abspath("${path.root}/../manifests/rbac")
  ssh_private_key_path = pathexpand("~/.ssh/id_rsa_tofu")
  vault_script_path    = "${local.scripts_dir}/install-vault.sh"
  vault_ingress_path   = abspath("${path.root}/../manifests/vault-ingress.yaml")
  vault_values_path    = abspath("${path.root}/../manifests/vault/helm-values.yaml")
  configure_vault_script_path = "${local.scripts_dir}/configure-vault.sh"
  vault_policy_path    = abspath("${path.root}/../manifests/vault/policy.hcl")
  vault_test_pod_path  = abspath("${path.root}/../manifests/vault/test-pod.yaml")
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

resource "null_resource" "install_flannel" {
  depends_on = [module.k8s_master]

  # Без triggers provisioner выполняется только при создании ресурса.
  # После пересоздания VM tofu считает Flannel уже установленным и скрипт не копирует.
  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.flannel_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    content     = file(local.flannel_script_path)
    destination = "/tmp/install-flannel.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-flannel.sh",
      "chmod +x /tmp/install-flannel.sh",
      "/tmp/install-flannel.sh"
    ]
  }
}

resource "null_resource" "install_metallb" {
  depends_on = [null_resource.install_flannel]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.metallb_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    content     = file(local.metallb_script_path)
    destination = "/tmp/install-metallb.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-metallb.sh",
      "chmod +x /tmp/install-metallb.sh",
      "/tmp/install-metallb.sh"
    ]
  }
}

resource "null_resource" "install_ingress" {
  depends_on = [null_resource.install_metallb]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.ingress_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    content     = file(local.ingress_script_path)
    destination = "/tmp/install-ingress.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-ingress.sh",
      "chmod +x /tmp/install-ingress.sh",
      "/tmp/install-ingress.sh"
    ]
  }
}

resource "null_resource" "install_argocd" {
  depends_on = [null_resource.install_ingress]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.argocd_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "10m"
  }

  provisioner "file" {
    content     = file(local.argocd_script_path)
    destination = "/tmp/install-argocd.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-argocd.sh",
      "chmod +x /tmp/install-argocd.sh",
      "/tmp/install-argocd.sh"
    ]
  }
}

resource "null_resource" "setup_gitops" {
  depends_on = [null_resource.install_argocd]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.gitops_script_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "10m"
  }

  provisioner "file" {
    content     = file(local.gitops_script_path)
    destination = "/tmp/setup-gitops.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/setup-gitops.sh",
      "chmod +x /tmp/setup-gitops.sh",
      "/tmp/setup-gitops.sh"
    ]
  }
}

resource "null_resource" "install_rbac" {
  depends_on = [null_resource.install_argocd]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.rbac_script_path)
    manifests  = sha256(join("", [
      filesha256("${local.rbac_dir}/developer.yaml"),
      filesha256("${local.rbac_dir}/devops.yaml"),
      filesha256("${local.rbac_dir}/user.yaml")
    ]))
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  # provisioner "file" не заливает каталог в /tmp/rbac/: scp ждет файл.
  # Сначала mkdir, потом каждый YAML как content (тот же прием, что для скриптов).
  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/rbac"]
  }

  provisioner "file" {
    content     = file("${local.rbac_dir}/developer.yaml")
    destination = "/tmp/rbac/developer.yaml"
  }

  provisioner "file" {
    content     = file("${local.rbac_dir}/devops.yaml")
    destination = "/tmp/rbac/devops.yaml"
  }

  provisioner "file" {
    content     = file("${local.rbac_dir}/user.yaml")
    destination = "/tmp/rbac/user.yaml"
  }

  provisioner "file" {
    content     = file(local.rbac_script_path)
    destination = "/tmp/install-rbac.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-rbac.sh /tmp/rbac/*.yaml",
      "chmod +x /tmp/install-rbac.sh",
      "/tmp/install-rbac.sh"
    ]
  }
}

resource "null_resource" "test_rbac" {
  depends_on = [null_resource.install_rbac]

  triggers = {
    master_ip  = module.master_vm.ip
    script_sha = filesha256(local.rbac_test_script_path)
    rbac       = null_resource.install_rbac.id
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    content     = file(local.rbac_test_script_path)
    destination = "/tmp/test-rbac.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/test-rbac.sh",
      "chmod +x /tmp/test-rbac.sh",
      "/tmp/test-rbac.sh"
    ]
  }
}

resource "null_resource" "install_vault" {
  depends_on = [null_resource.install_ingress] # Зависит от Ingress-контроллера

  triggers = {
    master_ip   = module.master_vm.ip
    script_sha  = filesha256(local.vault_script_path)
    ingress_sha = filesha256(local.vault_ingress_path)
    values_sha  = filesha256(local.vault_values_path)
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "15m"
  }

  # Копируем скрипт
  provisioner "file" {
    content     = file(local.vault_script_path)
    destination = "/tmp/install-vault.sh"
  }

  # Копируем Ingress-манифест
  provisioner "file" {
    content     = file(local.vault_ingress_path)
    destination = "/tmp/vault-ingress.yaml"
  }

  provisioner "file" {
    content     = file(local.vault_values_path)
    destination = "/tmp/vault-values.yaml"
  }

  # Выполняем установку и применяем Ingress
  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/install-vault.sh /tmp/vault-ingress.yaml /tmp/vault-values.yaml",
      "chmod +x /tmp/install-vault.sh",
      "/tmp/install-vault.sh"
    ]
  }
}

resource "null_resource" "configure_vault" {
  depends_on = [null_resource.install_vault]

  triggers = {
    master_ip     = module.master_vm.ip
    script_sha    = filesha256(local.configure_vault_script_path)
    policy_sha    = filesha256(local.vault_policy_path)
    vault_install = null_resource.install_vault.id
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  # Копируем скрипт
  provisioner "file" {
    content     = file(local.configure_vault_script_path)
    destination = "/tmp/configure-vault.sh"
  }

  # Копируем политику
  provisioner "file" {
    content     = file(local.vault_policy_path)
    destination = "/tmp/vault-policy.hcl"
  }

  # Выполняем настройку
  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/configure-vault.sh /tmp/vault-policy.hcl",
      "chmod +x /tmp/configure-vault.sh",
      "/tmp/configure-vault.sh"
    ]
  }
}

resource "null_resource" "test_vault_integration" {
  depends_on = [null_resource.configure_vault]

  triggers = {
    master_ip = module.master_vm.ip
    pod_sha   = filesha256(local.vault_test_pod_path)
    vault_cfg = null_resource.configure_vault.id
  }

  connection {
    type    = "ssh"
    user    = "ubuntu"
    host    = module.master_vm.ip
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    content     = file(local.vault_test_pod_path)
    destination = "/tmp/test-pod.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/test-pod.yaml",
      "kubectl delete pod test-vault-pod -n default --ignore-not-found",
      "kubectl apply -f /tmp/test-pod.yaml",
      "sleep 15",
      "kubectl logs test-vault-pod -n default || true"
    ]
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