#!/bin/bash
# ============================================
# Шаг 7: Настройка GitOps-цикла через CLI
# ============================================
# Описание: Настройка ArgoCD для работы с Git-репозиторием.
# Автор: brooh2121
# Дата: 2026-08-25
# ============================================

set -e

VM_NAME="k8s-master"
NAMESPACE="argocd"
ARGOCD_SERVER="argocd-server.$NAMESPACE:443"  # Внутренний адрес сервиса
REPO_URL="https://github.com/brooh2121/argocd-apps.git"  # ЗАМЕНИТЕ НА ВАШ РЕПО
APP_NAME="nginx"
APP_PATH="."  # Путь к манифестам в репозитории

echo "[STEP 7] Setting up GitOps cycle..."

# 1. Устанавливаем ArgoCD CLI на мастер-ноду
echo "Installing ArgoCD CLI..."
multipass exec $VM_NAME -- bash -c "
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
"

# 2. Получаем пароль администратора
echo "Getting admin password..."
ARGOCD_PASSWORD=$(multipass exec $VM_NAME -- kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# 3. Логинимся в ArgoCD API
echo "Logging in to ArgoCD API..."
multipass exec $VM_NAME -- argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure

# 4. Добавляем Git-репозиторий
echo "Adding Git repository..."
multipass exec $VM_NAME -- argocd repo add $REPO_URL --insecure

# 5. Создаём приложение
echo "Creating application $APP_NAME..."
multipass exec $VM_NAME -- argocd app create $APP_NAME \
    --repo $REPO_URL \
    --path $APP_PATH \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace default \
    --sync-policy none

# 6. Синхронизируем приложение
echo "Syncing application $APP_NAME..."
multipass exec $VM_NAME -- argocd app sync $APP_NAME

# 7. Проверяем статус
echo "Checking application status..."
multipass exec $VM_NAME -- argocd app get $APP_NAME

echo ""
echo "=== GitOps Setup Complete ==="
echo "Application: $APP_NAME"
echo "Repository: $REPO_URL"
echo "=================================="
echo ""
echo "[STEP 7] GitOps cycle configured."