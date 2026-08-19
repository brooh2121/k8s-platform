#!/bin/bash
# ============================================
# Шаг 3: Установка MetalLB (балансировщик нагрузки)
# ============================================
# Описание: Установка MetalLB для предоставления внешних IP.
# Автор: brooh2121
# Дата: 2026-08-19
# ============================================

set -e

VM_NAME="k8s-master"

echo "[STEP 3] Installing MetalLB..."

# Устанавливаем MetalLB
echo "Applying MetalLB manifests..."
multipass exec $VM_NAME -- kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to be ready..."
# Ждём, пока все поды MetalLB запустятся
for i in {1..20}; do
    READY=$(multipass exec $VM_NAME -- kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    if [ "$READY" -eq 2 ]; then
        echo "MetalLB pods are running."
        break
    fi
    echo "  Waiting for MetalLB pods (attempt $i)..."
    sleep 5
done

# Проверяем статус подов
echo "=== MetalLB pods ==="
multipass exec $VM_NAME -- kubectl get pods -n metallb-system

echo "[STEP 3] MetalLB installed."