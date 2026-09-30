#!/bin/bash
# ============================================
# Установка HashiCorp Vault (Dev Mode)
# ============================================
# Выполняется на мастер-ноде.
# ============================================

set -e

echo "[Vault] Installing HashiCorp Vault in Dev Mode..."

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

install_helm

echo "[Vault] Creating namespace vault..."
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# helm.releases.hashicorp.com часто недоступен (geo-block).
# Chart берем с GitHub, тот же vault-helm.
VAULT_HELM_TAG="v0.29.1"
VAULT_HELM_DIR="/tmp/vault-helm-${VAULT_HELM_TAG#v}"
echo "[Vault] Downloading vault-helm ${VAULT_HELM_TAG} from GitHub..."
curl -fsSL -o /tmp/vault-helm.tgz \
  "https://github.com/hashicorp/vault-helm/archive/refs/tags/${VAULT_HELM_TAG}.tar.gz"
rm -rf "$VAULT_HELM_DIR"
tar -xzf /tmp/vault-helm.tgz -C /tmp
rm -f /tmp/vault-helm.tgz

echo "[Vault] Installing/upgrading Vault (dev mode, root token=root)..."
helm upgrade --install vault "$VAULT_HELM_DIR" \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=true"

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

if [ -f /tmp/vault-ingress.yaml ]; then
    echo "[Vault] Applying Ingress..."
    kubectl apply -f /tmp/vault-ingress.yaml
fi

echo "[Vault] Vault installed and running."
kubectl get pods -n vault
kubectl get ingress -n vault

echo "[Vault] Configuring Kubernetes auth method..."