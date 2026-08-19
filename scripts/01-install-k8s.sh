#!/bin/bash
# ============================================
# Шаг 1: Установка Kubernetes и инициализация кластера
# ============================================
# Описание: Установка Docker, kubeadm, kubelet, kubectl.
# Параметры: $1 - тип ноды (master или worker)
# Автор: brooh2121
# Дата: 2026-08-17
# ============================================

set -e
export DEBIAN_FRONTEND=noninteractive

NODE_NAME=$1

if [ -z "$NODE_NAME" ]; then
    echo "[ERROR] Node name not specified. Usage: $0 [master|worker1|worker2]"
    exit 1
fi

VM_NAME="k8s-$NODE_NAME"

# --- Функция установки пакетов (общая для всех нод) ---
install_packages() {
    echo "Installing packages on $(hostname)..."

    # Отключаем swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Устанавливаем зависимости
    sudo -E apt-get update
    sudo -E apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    # Устанавливаем Docker + containerd
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo -E apt-get update
    sudo -E apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER

    # Устанавливаем kubeadm, kubelet, kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo -E apt-get update
    sudo -E apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    # Модули ядра
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter

    # sysctl
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system

    # --- Настройка containerd ---
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

    # SystemdCgroup
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    # Включаем поддержку certs.d
    sudo sed -i '/\[plugins\."io.containerd.grpc.v1.cri"\.registry\]/a\  config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml

    # Зеркало для registry.k8s.io
    sudo mkdir -p /etc/containerd/certs.d/registry.k8s.io
    cat <<EOF | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml
server = "https://registry.k8s.io"

[host."https://registry.aliyuncs.com/google_containers"]
  capabilities = ["pull", "resolve"]
  override_path = true
EOF

    # Явно указываем sandbox_image
    sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.10.2"|' /etc/containerd/config.toml

    sudo systemctl restart containerd
    sudo systemctl enable containerd
    sudo systemctl enable kubelet

    # Предварительно скачиваем pause (очень желательно)
    echo "Pre-pulling pause image..."
    sudo ctr -n k8s.io images pull registry.aliyuncs.com/google_containers/pause:3.10.2 || true
    sudo ctr -n k8s.io images tag \
        registry.aliyuncs.com/google_containers/pause:3.10.2 \
        registry.k8s.io/pause:3.10.2 || true

    echo "Packages installed on $(hostname)"
}

# --- Основная логика скрипта ---

# Копируем функцию установки на VM
multipass exec $VM_NAME -- bash -c "$(declare -f install_packages); install_packages"

if [ "$NODE_NAME" == "master" ]; then
    NODE_TYPE="master"
    echo "[MASTER] Initializing cluster..."

    # Получаем установленную версию kubeadm
    K8S_VERSION=$(multipass exec $VM_NAME -- kubeadm version -o short)
    echo "[MASTER] Using Kubernetes version: $K8S_VERSION"

    # Инициализируем кластер с указанием реестра
    multipass exec $VM_NAME -- sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository=registry.aliyuncs.com/google_containers

	# Узнаём имя пользователя в VM (обычно ubuntu)
    USER=$(multipass exec $VM_NAME -- whoami)
	
	# Настраиваем kubectl
	echo "Настраиваем kubectl ..."
    multipass exec $VM_NAME -- mkdir -p /home/$USER/.kube
    multipass exec $VM_NAME -- sudo cp /etc/kubernetes/admin.conf /home/$USER/.kube/config
    multipass exec $VM_NAME -- sudo chown $USER:$USER /home/$USER/.kube/config

    # Получаем токен для подключения воркеров
    echo "[MASTER] Cluster initialized. Getting join token..."
    JOIN_COMMAND=$(multipass exec $VM_NAME -- sudo kubeadm token create --print-join-command)
    
    # Сохраняем токен в файл на WSL для использования воркерами
    echo "$JOIN_COMMAND" > /tmp/kubeadm-join-command
    echo "[MASTER] Join command saved to /tmp/kubeadm-join-command"

elif [[ "$NODE_NAME" =~ ^worker[0-9]+$ ]]; then
    NODE_TYPE="worker"
	
    echo "[WORKER] Waiting for master to initialize..."

    # Ждем, пока мастер создаст файл с токеном (максимум 30 секунд)
    for i in {1..30}; do
        if [ -f /tmp/kubeadm-join-command ]; then
            break
        fi
        echo "Waiting for join command (attempt $i)..."
        sleep 2
    done

    if [ ! -f /tmp/kubeadm-join-command ]; then
        echo "[ERROR] Join command file not found after 60 seconds. Exiting."
        exit 1
    fi

    JOIN_COMMAND=$(cat /tmp/kubeadm-join-command)
    echo "[WORKER] Connecting to cluster with: $JOIN_COMMAND"

    # Подключаем воркер к кластеру
    multipass exec $VM_NAME -- sudo $JOIN_COMMAND

    echo "[WORKER] Connected to cluster successfully."
else
    echo "[ERROR] Unknown node name: $NODE_NAME. Must be 'master' or 'workerX'."
    exit 1
fi

echo "[STEP 1] Completed on $VM_NAME"