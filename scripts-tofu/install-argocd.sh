#!/bin/bash
# ============================================
# Установка ArgoCD (выполняется на master)
# ============================================

set -e

NAMESPACE="argocd"

echo "[ArgoCD] Installing ArgoCD with custom Redis image..."

echo "[ArgoCD] Removing old ApplicationSet CRD (if exists)..."
kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true

echo "[ArgoCD] Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "[ArgoCD] Downloading official install manifest..."
curl -fsSL -o /tmp/argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[ArgoCD] Patching Redis image..."
sed -i 's|image:.*\(redis[:@][^ ]*\).*|image: redis:7.2-alpine|g' /tmp/argocd-install.yaml
grep -n "image:.*redis" /tmp/argocd-install.yaml || true

echo "[ArgoCD] Applying manifest (server-side)..."
kubectl apply --server-side --force-conflicts -n "$NAMESPACE" -f /tmp/argocd-install.yaml

echo "[ArgoCD] Waiting for pods to be Running..."
for i in {1..30}; do
    RUNNING=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    TOTAL=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "[ArgoCD] All pods are running."
        break
    fi
    echo "  Waiting for ArgoCD pods (attempt $i)..."
    sleep 5
done

echo "[ArgoCD] Patching argocd-server service to LoadBalancer..."
kubectl patch svc argocd-server -n "$NAMESPACE" -p '{"spec": {"type": "LoadBalancer"}}'

sleep 10
ARGOCD_IP=$(kubectl get svc -n "$NAMESPACE" argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
ARGOCD_PASSWORD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "not found")

echo ""
echo "=== ArgoCD Installation Complete ==="
echo "IP Address: $ARGOCD_IP"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo "========================================"

kubectl get ns "$NAMESPACE"
kubectl get pods -n "$NAMESPACE"
