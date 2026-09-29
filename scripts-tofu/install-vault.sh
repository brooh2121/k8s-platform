#!/bin/bash
# ============================================
# Установка HashiCorp Vault (Dev Mode)
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

echo "[Vault] Installing HashiCorp Vault in Dev Mode..."

# 1. Добавляем репозиторий HashiCorp
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Создаём неймспейс
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# 3. Устанавливаем Vault в dev-режиме
#    Мы задаём корневой токен "root" для удобства тестирования.
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root"

# 4. Ждём, пока под запустится
echo "[Vault] Waiting for Vault pod to be ready..."
for i in {1..20}; do
    READY=$(kubectl get pods -n vault --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(kubectl get pods -n vault --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "[Vault] Vault pod is running."
        break
    fi
    echo "  Waiting for Vault pod (attempt $i)..."
    sleep 5
done

echo "[Vault] Vault installed and running."
kubectl get pods -n vault