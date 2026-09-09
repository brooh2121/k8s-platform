# ==============================================
# Конфигурация провайдера и версии
# ==============================================
terraform {
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "~> 1.7"
    }
  }
}

provider "multipass" {
  # Базовые настройки провайдера. Можно оставить пустым.
}

# ==============================================
# Ресурсы: Виртуальные машины
# ==============================================

# --- МАСТЕР-НОДА ---
resource "multipass_instance" "master" {
  name   = "k8s-master"
  image  = "lts"      # Ubuntu 22.04 LTS
  cpus   = 2
  memory = "2G"
  disk   = "10G"

  # Добавляем наш SSH-ключ в VM через cloud-init
  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF

  # Установка Kubernetes и инициализация кластера
  provisioner "remote-exec" {
    inline = [
      # 1. Обновляем систему и устанавливаем базовые пакеты
      "sudo apt-get update -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",

      # 2. Устанавливаем Docker
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker $USER",

      # 3. Устанавливаем kubeadm, kubelet, kubectl
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",

      # 4. Настраиваем containerd (cgroups и зеркало)
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      # Настройка зеркала для containerd
      "sudo mkdir -p /etc/containerd/certs.d/registry.k8s.io",
      "echo 'server = \"https://registry.k8s.io\"' | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '[host.\"https://registry.aliyuncs.com/google_containers\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  capabilities = [\"pull\", \"resolve\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  override_path = true' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "sudo systemctl restart containerd",

      # 5. Инициализируем кластер с зеркалом
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository=registry.aliyuncs.com/google_containers",

      # 6. Настраиваем kubectl для текущего пользователя
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",

      # 7. Сохраняем команду join в файл (используется воркерами)
      "sudo kubeadm token create --print-join-command | sudo tee /tmp/join-command",
      "sudo chmod 644 /tmp/join-command"   # Делаем файл читаемым для всех
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.ipv4[0]
      timeout     = "10m"
      agent       = true   # Используем ssh-agent для аутентификации
    }
  }
}

# --- ВОРКЕР-НОДА 1 ---
resource "multipass_instance" "worker1" {
  name   = "k8s-worker1"
  image  = "lts"
  cpus   = 2
  memory = "2G"
  disk   = "10G"

  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF

  # Ждём, пока мастер создаст файл с командой join
  depends_on = [multipass_instance.master]

  provisioner "remote-exec" {
    inline = [
      # 1. Установка базовых пакетов
      "sudo apt-get update -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",

      # 2. Установка Docker
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker $USER",

      # 3. Установка kubeadm, kubelet, kubectl
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",

      # 4. Настройка containerd (cgroups и зеркало)
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo mkdir -p /etc/containerd/certs.d/registry.k8s.io",
      "echo 'server = \"https://registry.k8s.io\"' | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '[host.\"https://registry.aliyuncs.com/google_containers\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  capabilities = [\"pull\", \"resolve\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  override_path = true' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "sudo systemctl restart containerd",

      # 5. Получаем команду join с мастера
      "JOIN_CMD=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${multipass_instance.master.ipv4[0]} 'sudo cat /tmp/join-command')",
      "sudo $JOIN_CMD"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.ipv4[0]
      timeout     = "10m"
      agent       = true
    }
  }
}

# --- ВОРКЕР-НОДА 2 ---
resource "multipass_instance" "worker2" {
  name   = "k8s-worker2"
  image  = "lts"
  cpus   = 2
  memory = "2G"
  disk   = "10G"

  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF

  depends_on = [multipass_instance.master]

  provisioner "remote-exec" {
    inline = [
      # Аналогичные команды, как в worker1
      "sudo apt-get update -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker $USER",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo mkdir -p /etc/containerd/certs.d/registry.k8s.io",
      "echo 'server = \"https://registry.k8s.io\"' | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '[host.\"https://registry.aliyuncs.com/google_containers\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  capabilities = [\"pull\", \"resolve\"]' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "echo '  override_path = true' | sudo tee -a /etc/containerd/certs.d/registry.k8s.io/hosts.toml",
      "sudo systemctl restart containerd",
      "JOIN_CMD=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${multipass_instance.master.ipv4[0]} 'sudo cat /tmp/join-command')",
      "sudo $JOIN_CMD"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.ipv4[0]
      timeout     = "10m"
      agent       = true
    }
  }
}