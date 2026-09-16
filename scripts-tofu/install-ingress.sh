#!/bin/bash
# ============================================
# Установка NGINX Ingress Controller
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

echo "[Ingress] Installing NGINX Ingress Controller..."

# 1. Устанавливаем Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml

# 2. Ждём, пока поды запустятся
echo "[Ingress] Waiting for Ingress Controller pods to be ready..."
for i in {1..30}; do
    READY=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "[Ingress] All pods are running."
        break
    fi
    echo "  Waiting for Ingress Controller pods (attempt $i)..."
    sleep 5
done

# 3. Получаем IP-адрес Ingress-контроллера
sleep 10
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
echo "[Ingress] Ingress Controller IP: $INGRESS_IP"

kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx