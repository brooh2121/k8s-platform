#!/bin/bash
# ============================================
# Скрипт установки Kubernetes на одну ноду (внутри VM)
# ============================================
# Параметры: $1 - тип ноды (master или worker)
#            $2 - IP мастер-ноды (для воркеров)
# ============================================

set -e
export DEBIAN_FRONTEND=noninteractive

NODE_TYPE=$1
MASTER_IP=$2

# Установка Docker
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Установка kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Настройка containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Логика для мастера или воркера
if [ "$NODE_TYPE" == "master" ]; then
    # Инициализация кластера
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository=registry.aliyuncs.com/google_containers
    
    # Настройка kubectl
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Сохраняем команду join
    sudo kubeadm token create --print-join-command > /tmp/join-command
    sudo chmod 644 /tmp/join-command
elif [ "$NODE_TYPE" == "worker" ]; then
    # Подключение к мастеру
    JOIN_CMD=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP 'sudo cat /tmp/join-command')
    sudo $JOIN_CMD
fi