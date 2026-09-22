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

echo "[ArgoCD] Waiting for core Deployments to become Available..."
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-repo-server --timeout=180s
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-application-controller --timeout=180s || \
  kubectl wait -n "$NAMESPACE" --for=condition=available statefulset/argocd-application-controller --timeout=180s || true
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-server --timeout=180s

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
