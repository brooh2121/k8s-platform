#!/bin/bash
# ============================================
# Установка HashiCorp Vault (standalone + file PVC)
# ============================================
# Выполняется на мастер-ноде.
#
# helm upgrade с -dev на PVC не работает: у StatefulSet
# volumeClaimTemplates неизменяемы. Старый -dev STS снимаем.
# На kubeadm нет StorageClass - ставим rancher local-path.
# После старта Vault sealed: init (1 ключ) и unseal.
# ============================================

set -e

echo "[Vault] Installing HashiCorp Vault (standalone)..."

install_helm() {
    if command -v helm >/dev/null 2>&1; then
        echo "[Vault] Helm already installed: $(helm version --short)"
        return
    fi

    echo "[Vault] Helm not found, installing..."
    HELM_VERSION="v3.16.4"
    curl -fsSL -o /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
    tar -xzf /tmp/helm.tgz -C /tmp
    sudo install -m 555 /tmp/linux-amd64/helm /usr/local/bin/helm
    rm -rf /tmp/helm.tgz /tmp/linux-amd64
    helm version --short
}

install_local_path() {
    if kubectl get storageclass local-path >/dev/null 2>&1; then
        echo "[Vault] StorageClass local-path already exists."
        return
    fi

    echo "[Vault] Installing rancher local-path provisioner..."
    LOCAL_PATH_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml"
    kubectl apply -f "$LOCAL_PATH_URL"
    kubectl rollout status deployment/local-path-provisioner -n local-path-storage --timeout=180s
}

remove_dev_statefulset() {
    if ! kubectl get statefulset vault -n vault >/dev/null 2>&1; then
        return
    fi
    ARGS=$(kubectl get statefulset vault -n vault -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || true)
    if echo "$ARGS" | grep -q -- '-dev'; then
        echo "[Vault] Existing STS is still -dev; Helm cannot add PVC templates. Recreating release..."
        helm uninstall vault -n vault || true
        kubectl delete statefulset vault -n vault --wait=true || true
        kubectl delete pvc -n vault --all --wait=true || true
    fi
}

# vault status в sealed / not initialized даёт exit 2 - это норма, не ошибка.
vault_status_json() {
    kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null || true
}

vault_status_field() {
    local field="$1"
    python3 -c '
import json, sys
field = sys.argv[1]
raw = sys.stdin.read()
start = raw.find("{")
if start < 0:
    sys.exit(1)
data = json.loads(raw[start:])
if field not in data:
    sys.exit(1)
print("yes" if data[field] else "no")
' "$field"
}

wait_vault_api() {
    echo "[Vault] Waiting for vault-0 API (Running != Ready, sealed is OK)..."
    for i in $(seq 1 36); do
        PHASE=$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || true)
        STATUS=$(vault_status_json)
        if [ "$PHASE" = "Running" ] && printf '%s' "$STATUS" | vault_status_field initialized >/dev/null 2>&1; then
            echo "[Vault] vault-0 API answers."
            return
        fi
        echo "  Waiting for vault API (attempt $i, phase=${PHASE:-none})..."
        sleep 5
    done
    echo "[Vault] vault-0 API did not answer."
    kubectl get pods -n vault -o wide || true
    kubectl describe pod vault-0 -n vault || true
    kubectl logs vault-0 -n vault --tail=30 || true
    exit 1
}

reset_vault_storage() {
    echo "[Vault] Deleting PVC data-vault-0 so lab can init again (unseal keys are gone)..."
    kubectl delete pod vault-0 -n vault --wait=true --ignore-not-found || true
    kubectl delete pvc data-vault-0 -n vault --wait=true --ignore-not-found || true
    wait_vault_api
}

init_and_unseal() {
    echo "[Vault] Checking init/unseal..."
    kubectl exec -n vault vault-0 -- vault status || true

    STATUS=$(vault_status_json)
    INITIALIZED=$(printf '%s' "$STATUS" | vault_status_field initialized)
    SEALED=$(printf '%s' "$STATUS" | vault_status_field sealed)
    echo "[Vault] parsed initialized=${INITIALIZED} sealed=${SEALED}"

    if [ "$INITIALIZED" = "yes" ] && ! kubectl get secret vault-init -n vault >/dev/null 2>&1; then
        echo "[Vault] Initialized on PVC, Secret vault-init missing. Keys cannot be recovered."
        reset_vault_storage
        STATUS=$(vault_status_json)
        INITIALIZED=$(printf '%s' "$STATUS" | vault_status_field initialized)
        SEALED=$(printf '%s' "$STATUS" | vault_status_field sealed)
    fi

    if [ "$INITIALIZED" != "yes" ]; then
        echo "[Vault] Initializing (1 share / 1 threshold, lab only)..."
        kubectl exec -n vault vault-0 -- vault operator init \
          -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init.json
        python3 -c '
import json
raw = open("/tmp/vault-init.json").read()
data = json.loads(raw[raw.find("{"):])
open("/tmp/vault-init.json","w").write(json.dumps(data))
print(data["unseal_keys_b64"][0])
print(data["root_token"])
' > /tmp/vault-init.kv
        UNSEAL=$(sed -n '1p' /tmp/vault-init.kv)
        ROOT=$(sed -n '2p' /tmp/vault-init.kv)
        kubectl create secret generic vault-init -n vault \
          --from-literal=unseal="$UNSEAL" \
          --from-literal=root="$ROOT" \
          --dry-run=client -o yaml | kubectl apply -f -
        chmod 600 /tmp/vault-init.json /tmp/vault-init.kv
        SEALED="yes"
    else
        UNSEAL=$(kubectl get secret vault-init -n vault -o jsonpath='{.data.unseal}' | base64 -d)
        ROOT=$(kubectl get secret vault-init -n vault -o jsonpath='{.data.root}' | base64 -d)
    fi

    if [ "$SEALED" = "yes" ]; then
        echo "[Vault] Unsealing..."
        kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL" >/dev/null
    fi

    echo "[Vault] Unsealed. Root token is in secret vault/vault-init (lab only)."
    kubectl exec -n vault vault-0 -- env VAULT_TOKEN="$ROOT" vault status
}

install_helm
install_local_path

echo "[Vault] Creating namespace vault..."
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

remove_dev_statefulset

VAULT_HELM_TAG="v0.29.1"
VAULT_HELM_DIR="/tmp/vault-helm-${VAULT_HELM_TAG#v}"
echo "[Vault] Downloading vault-helm ${VAULT_HELM_TAG} from GitHub..."
curl -fsSL -o /tmp/vault-helm.tgz \
  "https://github.com/hashicorp/vault-helm/archive/refs/tags/${VAULT_HELM_TAG}.tar.gz"
rm -rf "$VAULT_HELM_DIR"
tar -xzf /tmp/vault-helm.tgz -C /tmp
rm -f /tmp/vault-helm.tgz

VALUES="/tmp/vault-values.yaml"
if [ ! -f "$VALUES" ]; then
    echo "[Vault] Missing $VALUES"
    exit 1
fi

echo "[Vault] helm upgrade --install standalone..."
helm upgrade --install vault "$VAULT_HELM_DIR" \
  --namespace vault \
  --values "$VALUES"

wait_vault_api
init_and_unseal

if [ -f /tmp/vault-ingress.yaml ]; then
    echo "[Vault] Applying Ingress..."
    kubectl apply -f /tmp/vault-ingress.yaml
fi

echo "[Vault] Vault installed."
kubectl get pods -n vault
kubectl get pvc -n vault
kubectl get ingress -n vault
kubectl get sc
