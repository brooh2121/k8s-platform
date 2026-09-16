#!/bin/bash
# ============================================
# Установка MetalLB и настройка IP-пула
# ============================================
# Выполняется на мастер-ноде.
# Автоматически определяет подсеть и создаёт IP-пул.
# ============================================

set -e

echo "[MetalLB] Installing MetalLB..."

# 1. Устанавливаем MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# 2. Ждём, пока поды MetalLB запустятся
echo "[MetalLB] Waiting for MetalLB pods to be ready..."
for i in {1..20}; do
    READY=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "[MetalLB] All pods are running."
        break
    fi
    echo "  Waiting for MetalLB pods (attempt $i)..."
    sleep 5
done

# 3. Определяем подсеть мастер-ноды
MASTER_IP=$(hostname -I | awk '{print $1}')
SUBNET=$(echo $MASTER_IP | cut -d. -f1-3)
echo "[MetalLB] Detected subnet: $SUBNET.0/24"

# 4. Создаём IP-пул и L2Advertisement
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

echo "[MetalLB] MetalLB installed and configured."
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system