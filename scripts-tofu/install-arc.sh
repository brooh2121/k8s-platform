#!/bin/bash
# ============================================
# Установка Actions Runner Controller (ARC)
# ============================================
# Выполняется на мастер-ноде.
# Требует: PAT в /tmp/arc-token.txt
#
# Release helm: arc
# Deployment контроллера в chart называется arc-gha-rs-controller,
# не arc-gha-runner-scale-set-controller.
# ============================================

set -e

echo "[ARC] Installing Actions Runner Controller..."

if ! command -v helm >/dev/null 2>&1; then
    echo "[ARC] ERROR: helm not found on master."
    exit 1
fi

if [ ! -f /tmp/arc-token.txt ]; then
    echo "[ARC] ERROR: /tmp/arc-token.txt not found."
    exit 1
fi
chmod 600 /tmp/arc-token.txt

kubectl create namespace arc-systems --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -

echo "[ARC] Installing controller..."
helm upgrade --install arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

echo "[ARC] Helm controller resources:"
kubectl get deploy,pods -n arc-systems || true

echo "[ARC] Waiting for controller Deployment..."
CONTROLLER_DEPLOY=$(kubectl get deploy -n arc-systems -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$CONTROLLER_DEPLOY" ]; then
    echo "[ARC] ERROR: no Deployment in arc-systems after helm install."
    helm status arc -n arc-systems || true
    kubectl get all -n arc-systems || true
    exit 1
fi
echo "[ARC] Controller Deployment: $CONTROLLER_DEPLOY"
kubectl rollout status deployment/"$CONTROLLER_DEPLOY" -n arc-systems --timeout=180s

kubectl wait --for=condition=established \
  crd/autoscalingrunnersets.actions.github.com --timeout=60s

echo "[ARC] Creating GitHub secret..."
PAT=$(tr -d '\n' < /tmp/arc-token.txt)
kubectl create secret generic arc-github-secret \
  --namespace arc-runners \
  --from-literal=github_token="$PAT" \
  --dry-run=client -o yaml | kubectl apply -f -

# PAT регистрирует runner на репозиторий, не на весь аккаунт GitHub.
GITHUB_CONFIG_URL="https://github.com/brooh2121/github-actions-pipeline"
echo "[ARC] Installing runner scale set for ${GITHUB_CONFIG_URL}..."
helm upgrade --install arc-runner-set \
  --namespace arc-runners \
  --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
  --set githubConfigSecret="arc-github-secret" \
  --set runnerScaleSetName="arc-runner-set" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

echo "[ARC] Waiting for AutoscalingRunnerSet..."
sleep 10
kubectl get autoscalingrunnerset -n arc-runners || true

echo "[ARC] ARC installed."
kubectl get pods -n arc-systems
kubectl get pods -n arc-runners
kubectl get deploy -n arc-systems
