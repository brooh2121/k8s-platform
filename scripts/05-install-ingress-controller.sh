#!/bin/bash
# ============================================
# Шаг 5: Установка NGINX Ingress Controller
# ============================================
# Описание: Установка Ingress-контроллера для маршрутизации внешнего трафика.
# Автор: brooh2121
# Дата: 2026-08-25
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="ingress-nginx"

echo "[STEP 5] Installing NGINX Ingress Controller..."

# 1. Устанавливаем NGINX Ingress Controller
echo "Applying Ingress Controller manifests..."
multipass exec $VM_NAME -- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml

# 2. Ждём, пока поды Ingress Controller запустятся
echo "Waiting for Ingress Controller pods to be ready..."
for i in {1..30}; do
    RUNNING=$(multipass exec $VM_NAME -- kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(multipass exec $VM_NAME -- kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "All Ingress Controller pods are running."
        break
    fi
    echo "  Waiting for Ingress Controller pods (attempt $i)..."
    sleep 5
done

# 3. Получаем IP-адрес Ingress-контроллера
sleep 10
INGRESS_IP=$(multipass exec $VM_NAME -- kubectl get svc -n $NAMESPACE ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

echo ""
echo "=== Ingress Controller Installation Complete ==="
echo "IP Address: $INGRESS_IP"
echo "=================================================="
echo ""
echo "[STEP 5] Ingress Controller installed."