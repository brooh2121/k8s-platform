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

NODE_TYPE=$1

if [ -z "$NODE_TYPE" ]; then
    echo "[ERROR] Node type not specified. Usage: $0 [master|worker]"
    exit 1
fi

echo "[STEP 1] Installing and configuring Kubernetes on $NODE_TYPE node..."

VM_NAME="k8s-$NODE_TYPE"

# --- Функция установки пакетов (общая для всех нод) ---
install_packages() {
    echo "Installing packages on $(hostname)..."

    # Отключаем swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Устанавливаем зависимости
    sudo -E apt-get update
    sudo -E apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    # Устанавливаем Docker
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

    # Включаем модули ядра
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter

    # Настраиваем sysctl
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system

    # Настраиваем containerd
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd

    # Включаем kubelet
    sudo systemctl enable kubelet

    echo "Packages installed on $(hostname)"
}

# --- Основная логика скрипта ---

# Копируем функцию установки на VM
multipass exec $VM_NAME -- bash -c "$(declare -f install_packages); install_packages"

if [ "$NODE_TYPE" == "master" ]; then
    echo "[MASTER] Initializing cluster..."

    # Получаем установленную версию kubeadm
    K8S_VERSION=$(multipass exec $VM_NAME -- kubeadm version -o short)
    echo "[MASTER] Using Kubernetes version: $K8S_VERSION"

    # Инициализируем кластер с явным указанием версии
	echo "Инициализируем кластер кубера ..."
    multipass exec $VM_NAME -- sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository=registry.vk-cloud.net

    # Настраиваем kubectl
	echo "Настраиваем kubectl ..."
    multipass exec $VM_NAME -- mkdir -p $HOME/.kube
    multipass exec $VM_NAME -- sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    multipass exec $VM_NAME -- sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Получаем токен для подключения воркеров
    echo "[MASTER] Cluster initialized. Getting join token..."
    JOIN_COMMAND=$(multipass exec $VM_NAME -- sudo kubeadm token create --print-join-command)
    
    # Сохраняем токен в файл на WSL для использования воркерами
    echo "$JOIN_COMMAND" > /tmp/kubeadm-join-command
    echo "[MASTER] Join command saved to /tmp/kubeadm-join-command"

elif [ "$NODE_TYPE" == "worker" ]; then
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
    echo "[ERROR] Unknown node type: $NODE_TYPE"
    exit 1
fi

echo "[STEP 1] Completed on $VM_NAME"