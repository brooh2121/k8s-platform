#!/bin/bash
# ============================================
# Настройка Vault: Kubernetes Auth, Policy, Role
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

NAMESPACE="vault"
VAULT_POD="vault-0"

echo "[Vault] Configuring Kubernetes auth method..."

# 1. Включаем Kubernetes auth method
kubectl exec -n $NAMESPACE $VAULT_POD -- vault auth enable kubernetes 2>/dev/null || true

# 2. Настраиваем его
kubectl exec -n $NAMESPACE $VAULT_POD -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# 3. Копируем политику внутрь пода Vault
kubectl cp /tmp/vault-policy.hcl $NAMESPACE/$VAULT_POD:/tmp/policy.hcl

# 4. Создаём политику
kubectl exec -n $NAMESPACE $VAULT_POD -- vault policy write test-policy /tmp/policy.hcl

# 5. Создаём роль, привязанную к ServiceAccount "test-sa" в неймспейсе "default"
kubectl exec -n $NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/test-role \
  bound_service_account_names=test-sa \
  bound_service_account_namespaces=default \
  policies=test-policy \
  ttl=1h

# 6. Учебный секрет для injector (kv-v2 в dev уже на пути secret/)
echo "[Vault] Writing demo KV secret secret/test..."
kubectl exec -n $NAMESPACE $VAULT_POD -- vault kv put secret/test \
  username=demo \
  password=lab

echo "[Vault] Configuration complete."
kubectl exec -n $NAMESPACE $VAULT_POD -- vault auth list
kubectl exec -n $NAMESPACE $VAULT_POD -- vault policy list