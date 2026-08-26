#!/bin/bash
# ============================================
# Шаг 7: Настройка GitOps-цикла через CLI
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="argocd"
REPO_URL="https://github.com/brooh2121/argocd-apps.git"
APP_NAME="nginx"
APP_PATH="."

echo "[STEP 7] Setting up GitOps cycle..."

# 1. Устанавливаем ArgoCD CLI
echo "Installing ArgoCD CLI..."
multipass exec $VM_NAME -- bash -c '
  if ! command -v argocd &>/dev/null; then
    curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    rm -f /tmp/argocd-linux-amd64
  fi
  argocd version --client
'

# 2. Получаем пароль
echo "Getting admin password..."
ARGOCD_PASSWORD=$(multipass exec $VM_NAME -- kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Password: $ARGOCD_PASSWORD"

# 3. Получаем адрес ArgoCD Server (динамически)
echo "Detecting ArgoCD server address..."
ARGOCD_SERVER=$(multipass exec $VM_NAME -- bash -c '
  # Пробуем LoadBalancer External IP
  IP=$(kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || true)
  
  if [ -n "$IP" ] && [ "$IP" != "null" ]; then
    echo "${IP}:443"
  else
    # Fallback: Node InternalIP + NodePort
    IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}")
    PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath="{.spec.ports[?(@.name==\"https\")].nodePort}")
    echo "${IP}:${PORT}"
  fi
')

echo "Using ArgoCD server: $ARGOCD_SERVER"

# 4. Логинимся
echo "Logging in to ArgoCD..."
multipass exec $VM_NAME -- argocd login "$ARGOCD_SERVER" \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure \
  --grpc-web

# 5. Добавляем репозиторий
echo "Adding Git repository..."
multipass exec $VM_NAME -- argocd repo add "$REPO_URL" --insecure || true

# 6. Создаём приложение (идемпотентно)
echo "Creating application $APP_NAME..."
multipass exec $VM_NAME -- argocd app create "$APP_NAME" \
  --repo "$REPO_URL" \
  --path "$APP_PATH" \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy none \
  --upsert

# 7. Синхронизируем
echo "Syncing application..."
multipass exec $VM_NAME -- argocd app sync "$APP_NAME"

# 8. Статус
echo "Application status:"
multipass exec $VM_NAME -- argocd app get "$APP_NAME"

echo ""
echo "=== GitOps Setup Complete ==="
echo "Application : $APP_NAME"
echo "Repository  : $REPO_URL"
echo "ArgoCD URL  : https://$ARGOCD_SERVER"
echo "=================================="