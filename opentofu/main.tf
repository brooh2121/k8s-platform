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
      # 1. Обновляем систему и устанавливаем зависимости
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

      # 4. Настраиваем containerd (исправляем cgroup)
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo systemctl restart containerd",

      # 5. Инициализируем кластер (с зеркалом)
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository=registry.aliyuncs.com/google_containers",

      # 6. Настраиваем kubectl
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",

      # 7. Сохраняем команду join в файл для воркеров
      "sudo kubeadm token create --print-join-command | sudo tee /tmp/join-command"
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

  cloud_init = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_rsa_tofu.pub")}
  EOF

  # Ждём, пока мастер создаст файл с командой
  depends_on = [multipass_instance.master]

  provisioner "remote-exec" {
    inline = [
      # Установка зависимостей (как на мастере)
      "sudo apt-get update -y",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker $USER",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",

      # Чтение команды join с мастера (через ssh, так как файл на мастере)
      "JOIN_CMD=$(ssh -o StrictHostKeyChecking=no ubuntu@${multipass_instance.master.ipv4[0]} 'sudo cat /tmp/join-command')",
      "sudo $JOIN_CMD"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa_tofu")
      host        = self.ipv4[0]
      timeout     = "10m"
    }
  }
}

# Воркер-нода 2
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

  # Ждём, пока мастер создаст файл с командой
  depends_on = [multipass_instance.master]

  provisioner "remote-exec" {
    inline = [
      # Установка зависимостей (как на мастере)
      "sudo apt-get update -y",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker $USER",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",

      # Чтение команды join с мастера (через ssh, так как файл на мастере)
      "JOIN_CMD=$(ssh -o StrictHostKeyChecking=no ubuntu@${multipass_instance.master.ipv4[0]} 'sudo cat /tmp/join-command')",
      "sudo $JOIN_CMD"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa_tofu")
      host        = self.ipv4[0]
      timeout     = "10m"
    }
  }
}