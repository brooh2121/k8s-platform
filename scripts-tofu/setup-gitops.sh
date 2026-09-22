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
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
fi

# 2. Получаем пароль администратора
echo "[GitOps] Getting admin password..."
ARGOCD_PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# 3. Определяем адрес ArgoCD-сервера (LoadBalancer IP)
ARGOCD_IP=$(kubectl get svc argocd-server -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_SERVER="${ARGOCD_IP}:443"
echo "[GitOps] Using ArgoCD server: $ARGOCD_SERVER"

# 4. Логинимся в ArgoCD
echo "[GitOps] Logging in to ArgoCD..."
argocd login "$ARGOCD_SERVER" --username admin --password "$ARGOCD_PASSWORD" --insecure --grpc-web

# 5. Добавляем репозиторий
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
echo "ArgoCD URL  : https://$ARGOCD_SERVER"
echo "=================================="