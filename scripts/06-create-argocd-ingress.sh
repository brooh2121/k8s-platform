#!/bin/bash
# ============================================
# Шаг 6: Настройка Ingress для ArgoCD
# ============================================
# Описание: Применение Ingress-ресурса для доступа к ArgoCD через argocd.local.
# Автор: brooh2121
# Дата: 2026-08-25
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="argocd"
MANIFEST_FILE="manifests/argocd-ingress.yaml"

echo "[STEP 6] Creating Ingress for ArgoCD..."

# 1. Проверяем, существует ли файл с манифестом
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "[ERROR] Manifest file $MANIFEST_FILE not found."
    echo "Please create it before running this script."
    exit 1
fi

# 2. Передаём манифест на мастер-ноду
echo "Copying Ingress manifest to master node..."
multipass transfer $MANIFEST_FILE k8s-master:/tmp/argocd-ingress.yaml

# 3. Применяем манифест
echo "Applying ArgoCD Ingress manifest..."
multipass exec $VM_NAME -- kubectl apply -f /tmp/argocd-ingress.yaml

# 4. Получаем IP-адрес Ingress-контроллера (для информации)
INGRESS_IP=$(multipass exec $VM_NAME -- kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

# 5. Очищаем временный файл на мастер-ноде
multipass exec $VM_NAME -- rm -f /tmp/argocd-ingress.yaml

echo ""
echo "=== ArgoCD Ingress Setup Complete ==="
echo "ArgoCD URL: https://argocd.local"
echo "Ingress Controller IP: $INGRESS_IP"
echo ""
echo "Please add the following line to your Windows hosts file:"
echo "$INGRESS_IP argocd.local"
echo "========================================"
echo ""
echo "[STEP 6] ArgoCD Ingress configured."