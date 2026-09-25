#!/bin/bash
# ============================================
# Установка RBAC (ServiceAccounts, Roles, RoleBindings)
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

echo "[RBAC] Applying RBAC manifests..."

# Применяем все манифесты из папки rbac
kubectl apply -f /tmp/rbac/

echo "[RBAC] RBAC configured."
kubectl get serviceaccounts -A
kubectl get roles -A
kubectl get rolebindings -A