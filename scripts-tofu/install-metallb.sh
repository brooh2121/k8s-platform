#!/bin/bash
# ============================================
# Установка MetalLB (L2) на master
# ============================================
# hostname -I даёт несколько адресов (docker0, Flannel).
# Пул берём из InternalIP ноды, иначе L2 объявляет чужую подсеть.
# Apply пула без пула = LoadBalancer навсегда Pending.
# Если вебхук ещё не готов, kubectl apply падает; цикл не должен
# проглатывать ошибку и выходить 0.
# ============================================

set -e

echo "[MetalLB] Installing MetalLB..."

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

echo "[MetalLB] Waiting for CRDs and controller..."
kubectl wait --for=condition=established crd/ipaddresspools.metallb.io --timeout=120s
kubectl wait --for=condition=established crd/l2advertisements.metallb.io --timeout=120s
kubectl wait -n metallb-system --for=condition=available deployment/controller --timeout=180s
kubectl rollout status daemonset/speaker -n metallb-system --timeout=180s

NODE_IP=$(kubectl get node -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    echo "[MetalLB] ERROR: cannot read control-plane InternalIP."
    kubectl get nodes -o wide
    exit 1
fi
SUBNET=$(echo "$NODE_IP" | cut -d. -f1-3)
echo "[MetalLB] Node InternalIP: $NODE_IP, pool ${SUBNET}.240-${SUBNET}.250"

POOL_MANIFEST=$(cat <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${SUBNET}.240-${SUBNET}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
)

echo "[MetalLB] Applying IPAddressPool and L2Advertisement..."
APPLIED=0
for i in $(seq 1 30); do
    if echo "$POOL_MANIFEST" | kubectl apply -f -; then
        APPLIED=1
        break
    fi
    echo "  Waiting for MetalLB webhook (attempt $i)..."
    sleep 5
done
if [ "$APPLIED" -ne 1 ]; then
    echo "[MetalLB] ERROR: failed to apply IPAddressPool."
    kubectl get pods -n metallb-system -o wide
    kubectl logs -n metallb-system -l app=metallb,component=controller --tail=50 || true
    exit 1
fi

kubectl get ipaddresspools,l2advertisements -n metallb-system
kubectl get pods -n metallb-system
echo "[MetalLB] MetalLB installed and configured."
