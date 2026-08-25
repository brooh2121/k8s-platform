#!/bin/bash
# ============================================
# Шаг 4: Установка ArgoCD (с исправленным Redis)
# ============================================
# Описание: Установка ArgoCD с заменой образа Redis на рабочий.
# Автор: brooh2121
# Дата: 2026-08-25
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="argocd"

echo "[STEP 4] Installing ArgoCD with custom Redis image..."

# 1. Удаляем старый CRD ApplicationSet, если он есть (чтобы избежать ошибки)
echo "Removing old ApplicationSet CRD (if exists)..."
multipass exec $VM_NAME -- kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true

# 2. Создаём неймспейс
echo "Creating namespace $NAMESPACE..."
multipass exec $VM_NAME -- kubectl create namespace $NAMESPACE --dry-run=client -o yaml | multipass exec $VM_NAME -- kubectl apply -f -

# 3. Скачиваем манифест ArgoCD на мастер-ноду
echo "Downloading ArgoCD manifest..."
multipass exec $VM_NAME -- wget -q -O /tmp/argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Заменяем образ Redis на рабочий
echo "Patching Redis image..."
multipass exec $VM_NAME -- sed -i 's|image:.*\(redis[:@][^ ]*\).*|image: redis:7.2-alpine|g' /tmp/argocd-install.yaml

echo "Checking Redis image after patch..."
multipass exec $VM_NAME -- grep -n "image:.*redis" /tmp/argocd-install.yaml || true

# 5. Устанавливаем ArgoCD
echo "Installing ArgoCD from patched manifest..."
multipass exec $VM_NAME -- kubectl apply -n $NAMESPACE -f /tmp/argocd-install.yaml

# 6. Ждём, пока поды ArgoCD запустятся
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

# 7. Меняем сервис на LoadBalancer
echo "Patching argocd-server service to LoadBalancer..."
multipass exec $VM_NAME -- kubectl patch svc argocd-server -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}'

# 8. Ждём, пока MetalLB выдаст IP
echo "Waiting for LoadBalancer IP..."
sleep 10
ARGOCD_IP=$(multipass exec $VM_NAME -- kubectl get svc -n $NAMESPACE argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

# 9. Получаем пароль
ARGOCD_PASSWORD=$(multipass exec $VM_NAME -- kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "not found")

echo ""
echo "=== ArgoCD Installation Complete ==="
echo "IP Address: $ARGOCD_IP"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo "========================================"
echo ""
echo "[STEP 4] ArgoCD installed."