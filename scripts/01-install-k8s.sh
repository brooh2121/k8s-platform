#!/bin/bash
# ============================================
# Шаг 1: Установка Kubernetes на все ноды
# ============================================
# Описание: Установка Docker, kubeadm, kubelet, kubectl.
# Параметры: $1 - тип ноды (master или worker)
# Автор: brooh2121
# Дата: 2026-08-13
# ============================================

set -e

NODE_TYPE=$1

if [ -z "$NODE_TYPE" ]; then
    echo "[ERROR] Node type not specified. Usage: $0 [master|worker]"
    exit 1
fi

echo "[STEP 1] Installing Kubernetes on $NODE_TYPE node..."

# Определяем имя VM
VM_NAME="k8s-$NODE_TYPE"

# Создаем временный скрипт для установки на VM
echo "Creating temporary install script on $VM_NAME..."

# Копируем сам этот скрипт на VM, но с помощью heredoc мы создадим новый файл
multipass exec $VM_NAME -- bash -c "cat > /tmp/install-k8s.sh" <<'EOF'
#!/bin/bash
set -e

echo "Installing Kubernetes on $(hostname)..."

# Отключаем swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Устанавливаем зависимости
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Устанавливаем Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# Устанавливаем kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Включаем модули ядра для Kubernetes
cat <<EOF2 | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF2
sudo modprobe overlay
sudo modprobe br_netfilter

# Настраиваем sysctl
cat <<EOF2 | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF2
sudo sysctl --system

# Настраиваем containerd (драйвер cgroups)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Включаем kubelet
sudo systemctl enable kubelet

echo "Installation complete on $(hostname)"
EOF

# Делаем скрипт исполняемым и запускаем его на VM
echo "Running installation script on $VM_NAME..."
multipass exec $VM_NAME -- chmod +x /tmp/install-k8s.sh
multipass exec $VM_NAME -- sudo /tmp/install-k8s.sh

# Удаляем временный скрипт
multipass exec $VM_NAME -- rm -f /tmp/install-k8s.sh

echo "[STEP 1] Kubernetes installation completed on $VM_NAME"