#!/bin/bash
# ============================================
# Установка kube-prometheus-stack
# Prometheus + Grafana + Alertmanager
# ============================================
# Grafana persistence требует StorageClass.
# На kubeadm его нет: PVC остаётся Unbound, под Pending,
# helm --wait падает по таймауту. Ставим local-path,
# как в install-vault.sh, и явно указываем его Grafana.
# ============================================

set -e
trap 'echo "[MONITORING] ERROR line $LINENO exit $?"' ERR
export PATH="/usr/local/bin:$PATH"

echo "[MONITORING] Installing kube-prometheus-stack..."

install_helm() {
    if command -v helm >/dev/null 2>&1; then
        echo "[MONITORING] Helm already installed: $(helm version --short)"
        return
    fi
    echo "[MONITORING] Helm not found, installing..."
    HELM_VERSION="v3.16.4"
    curl -fsSL -o /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
    tar -xzf /tmp/helm.tgz -C /tmp
    sudo install -m 555 /tmp/linux-amd64/helm /usr/local/bin/helm
    rm -rf /tmp/helm.tgz /tmp/linux-amd64
    hash -r
    helm version --short
}

install_local_path() {
    if kubectl get storageclass local-path >/dev/null 2>&1; then
        echo "[MONITORING] StorageClass local-path already exists."
        return
    fi
    echo "[MONITORING] Installing rancher local-path provisioner..."
    LOCAL_PATH_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml"
    kubectl apply -f "$LOCAL_PATH_URL"
    kubectl rollout status deployment/local-path-provisioner -n local-path-storage --timeout=180s
}

install_helm
install_local_path

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# PVC Grafana без storageClassName не биндится: default SC на kubeadm нет.
# Уже созданный PVC без класса helm не чинит (поле почти неизменяемо) -
# удаляем только Unbound claim Grafana, релиз пересоздаст его с local-path.
GRAFANA_PVC=$(kubectl get pvc -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null | awk '/grafana/ && $3=="Pending" && ($2=="" || $2=="<none>") {print $1}')
if [ -n "$GRAFANA_PVC" ]; then
    echo "[MONITORING] Deleting unbound Grafana PVC without StorageClass: $GRAFANA_PVC"
    kubectl delete pvc -n monitoring $GRAFANA_PVC --wait=false
fi

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set grafana.adminPassword=admin123 \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi \
  --set grafana.persistence.storageClassName=local-path \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=128Mi \
  --set prometheusOperator.resources.requests.memory=128Mi \
  --set kube-state-metrics.resources.requests.memory=64Mi \
  --set nodeExporter.resources.requests.memory=32Mi \
  --timeout 10m \
  --wait

echo "[MONITORING] Waiting for pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=180s || true

echo "[MONITORING] Stack installed."
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
