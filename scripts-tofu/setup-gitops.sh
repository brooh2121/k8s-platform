#!/bin/bash
# ============================================
# Настройка GitOps-цикла через ArgoCD CLI
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

NAMESPACE="argocd"
REPO_URL="https://github.com/brooh2121/argocd-apps.git"  # ЗАМЕНИТЕ НА ВАШ РЕПО
APP_NAME="nginx"
APP_PATH="."

echo "[GitOps] Setting up GitOps cycle..."

# 1. Устанавливаем ArgoCD CLI (если не установлен)
if ! command -v argocd &> /dev/null; then
    echo "[GitOps] Installing ArgoCD CLI..."
    curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    rm -f /tmp/argocd-linux-amd64
fi

# 2. Ждём, пока repo-server и server будут Available
echo "[GitOps] Waiting for argocd-repo-server and argocd-server..."
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-repo-server --timeout=180s
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-server --timeout=180s

# 3. Получаем пароль администратора
echo "[GitOps] Getting admin password..."
ARGOCD_PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# 4. CLI с master: port-forward к argocd-server, без LoadBalancer и без записи kubeconfig.
# kubectl config set-context пишет config.lock; каталог ~/.kube часто root:root после kubeadm.
echo "[GitOps] Logging in via kubectl port-forward..."
argocd login --port-forward --port-forward-namespace "$NAMESPACE" \
  --username admin --password "$ARGOCD_PASSWORD" --insecure

LB_IP=$(kubectl get svc argocd-server -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [ -z "$LB_IP" ]; then
    echo "[GitOps] argocd-server LoadBalancer still pending (UI later). Check:"
    kubectl get svc argocd-server -n "$NAMESPACE"
    kubectl get ipaddresspools -n metallb-system || true
fi

# 6. Добавляем репозиторий
echo "[GitOps] Adding Git repository..."
argocd repo add "$REPO_URL" --insecure || true

# 6. Создаём приложение (идемпотентно)
echo "[GitOps] Creating application $APP_NAME..."
argocd app create "$APP_NAME" \
  --repo "$REPO_URL" \
  --path "$APP_PATH" \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy none \
  --upsert

# 7. Синхронизируем приложение
echo "[GitOps] Syncing application..."
argocd app sync "$APP_NAME"

# 8. Проверяем статус
echo "[GitOps] Application status:"
argocd app get "$APP_NAME"

echo ""
echo "=== GitOps Setup Complete ==="
echo "Application : $APP_NAME"
echo "Repository  : $REPO_URL"
echo "ArgoCD CLI  : argocd login --port-forward --port-forward-namespace argocd"
if [ -n "$LB_IP" ]; then
    echo "ArgoCD UI   : https://${LB_IP}"
fi
echo "=================================="