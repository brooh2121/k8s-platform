#!/bin/bash
# ============================================
# Шаг 3: Установка MetalLB и настройка IP-пула
# ============================================
# Описание: Установка MetalLB и создание IP-пула.
# Автор: brooh2121
# Дата: 2026-08-19
# ============================================

set -e

VM_NAME="k8s-master"

echo "[STEP 3] Installing MetalLB..."

# 1. Устанавливаем MetalLB
echo "Applying MetalLB manifests..."
multipass exec $VM_NAME -- kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# 2. Ждём, пока поды MetalLB запустятся
echo "Waiting for MetalLB pods to be ready..."
for i in {1..20}; do
    READY=$(multipass exec $VM_NAME -- kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    if [ "$READY" -eq 2 ]; then
        echo "MetalLB pods are running."
        break
    fi
    echo "  Waiting for MetalLB pods (attempt $i)..."
    sleep 5
done

# 3. Определяем подсеть для IP-пула
echo "Determining network subnet for IP pool..."
MASTER_IP=$(multipass exec $VM_NAME -- hostname -I | awk '{print $1}')
SUBNET=$(echo $MASTER_IP | cut -d. -f1-3)
echo "Using subnet: $SUBNET.0/24"

# 4. Создаём конфигурацию IP-пула
echo "Creating IPAddressPool and L2Advertisement..."
multipass exec $VM_NAME -- bash -c "
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $SUBNET.240-$SUBNET.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
"

# 5. Проверяем результат
echo "=== MetalLB pods ==="
multipass exec $VM_NAME -- kubectl get pods -n metallb-system

echo "=== IPAddressPool ==="
multipass exec $VM_NAME -- kubectl get ipaddresspools -n metallb-system

echo "[STEP 3] MetalLB installed and configured."