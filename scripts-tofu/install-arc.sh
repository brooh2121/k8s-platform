#!/bin/bash
# ============================================
# Установка Actions Runner Controller (ARC)
# ============================================
# Выполняется на мастер-ноде.
# Требует: PAT в /tmp/arc-token.txt
# ============================================

set -e

echo "[ARC] Installing Actions Runner Controller..."

# 1. Создаём неймспейсы
kubectl create namespace arc-systems --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -

# 2. Устанавливаем Controller
echo "[ARC] Installing controller..."
helm upgrade --install arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# 3. Ждём, пока controller запустится
echo "[ARC] Waiting for controller to be ready..."
kubectl rollout status deployment/arc-gha-runner-scale-set-controller -n arc-systems --timeout=180s

# 4. Создаём Secret с PAT
echo "[ARC] Creating GitHub secret..."
if [ ! -f /tmp/arc-token.txt ]; then
    echo "[ARC] ERROR: /tmp/arc-token.txt not found."
    exit 1
fi
PAT=$(cat /tmp/arc-token.txt)
kubectl create secret generic arc-github-secret \
  --namespace arc-runners \
  --from-literal=github_token="$PAT" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Устанавливаем Runner Scale Set
echo "[ARC] Installing runner scale set..."
helm upgrade --install arc-runner-set \
  --namespace arc-runners \
  --set githubConfigUrl="https://github.com/brooh2121" \
  --set githubConfigSecret="arc-github-secret" \
  --set runnerScaleSetName="arc-runner-set" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# 6. Ждём регистрации
echo "[ARC] Waiting for runner scale set..."
sleep 10
kubectl get autoscalingrunnerset -n arc-runners || true

echo "[ARC] ARC installed successfully."
kubectl get pods -n arc-systems
kubectl get pods -n arc-runners