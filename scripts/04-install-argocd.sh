#!/bin/bash
# ============================================
# Шаг 4: Установка ArgoCD
# ============================================
# Описание: Установка ArgoCD и настройка доступа через LoadBalancer.
# Автор: brooh2121
# Дата: 2026-08-19
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="argocd"

echo "[STEP 4] Installing ArgoCD..."

# 1. Создаём неймспейс
echo "Creating namespace $NAMESPACE..."
multipass exec $VM_NAME -- kubectl create namespace $NAMESPACE --dry-run=client -o yaml | multipass exec $VM_NAME -- kubectl apply -f -

# 2. Устанавливаем ArgoCD (исправленный манифест с правильным образом Redis)
echo "Installing ArgoCD..."
multipass exec $VM_NAME -- kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Ждём, пока поды ArgoCD запустятся
echo "Waiting for ArgoCD pods to be ready..."
for i in {1..30}; do
    RUNNING=$(multipass exec $VM_NAME -- kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(multipass exec $VM_NAME -- kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "All ArgoCD pods are running."
        break
    fi
    echo "  Waiting for ArgoCD pods (attempt $i)..."
    sleep 5
done

# 4. Меняем сервис на LoadBalancer
echo "Patching argocd-server service to LoadBalancer..."
multipass exec $VM_NAME -- kubectl patch svc argocd-server -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}'

# 5. Ждём, пока MetalLB выдаст IP
echo "Waiting for LoadBalancer IP..."
sleep 10
ARGOCD_IP=$(multipass exec $VM_NAME -- kubectl get svc -n $NAMESPACE argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

# 6. Получаем пароль
ARGOCD_PASSWORD=$(multipass exec $VM_NAME -- kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "not found")

echo ""
echo "=== ArgoCD Installation Complete ==="
echo "IP Address: $ARGOCD_IP"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo "========================================"
echo ""
echo "[STEP 4] ArgoCD installed."