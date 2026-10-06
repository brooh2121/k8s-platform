#!/bin/bash
# ============================================
# Настройка Vault: Kubernetes Auth, Policy, Role
# ============================================
# Выполняется на мастер-ноде.
# Root token берётся из secret vault-init (после init standalone).
# ============================================

set -e

NAMESPACE="vault"
VAULT_POD="vault-0"

if ! kubectl get secret vault-init -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "[Vault] Secret vault-init not found. Run install-vault.sh first."
    exit 1
fi

ROOT=$(kubectl get secret vault-init -n "$NAMESPACE" -o jsonpath='{.data.root}' | base64 -d)

vault_cli() {
    kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
      env VAULT_TOKEN="$ROOT" VAULT_ADDR=http://127.0.0.1:8200 "$@"
}

echo "[Vault] Configuring Kubernetes auth method..."

# kv-v2 в standalone сам не включается (в -dev путь secret/ уже есть)
vault_cli vault secrets enable -path=secret kv-v2 2>/dev/null || true

vault_cli vault auth enable kubernetes 2>/dev/null || true

vault_cli vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

kubectl cp /tmp/vault-policy.hcl "$NAMESPACE/$VAULT_POD:/tmp/policy.hcl"

vault_cli vault policy write test-policy /tmp/policy.hcl

vault_cli vault write auth/kubernetes/role/test-role \
  bound_service_account_names=test-sa \
  bound_service_account_namespaces=default \
  policies=test-policy \
  ttl=1h

echo "[Vault] Writing demo KV secret secret/test..."
vault_cli vault kv put secret/test \
  username=demo \
  password=lab

echo "[Vault] Configuration complete."
vault_cli vault auth list
vault_cli vault policy list
vault_cli vault kv get secret/test
