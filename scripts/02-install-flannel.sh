#!/bin/bash
# ============================================
# Шаг 2: Установка сетевого плагина Flannel
# ============================================
# Описание: Установка Flannel для сети Pod'ов.
# Автор: brooh2121
# Дата: 2026-08-18
# ============================================

set -e

VM_NAME="k8s-master"

echo "[STEP 2] Installing Flannel network plugin..."

# Применяем манифест Flannel
multipass exec $VM_NAME -- kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.25.6/Documentation/kube-flannel.yml

# Ждём, пока поды Flannel запустятся (максимум 60 секунд)
echo "Waiting for Flannel pods to be ready..."
sleep 10

# Проверяем статус подов Flannel
multipass exec $VM_NAME -- kubectl get pods -n kube-flannel

echo "[STEP 2] Flannel installed successfully."