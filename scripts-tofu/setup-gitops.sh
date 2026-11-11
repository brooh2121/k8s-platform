#!/bin/bash
# ============================================
# Настройка GitOps: Application в ArgoCD через kubectl
# ============================================
# CLI login (port-forward / --core) на этом стенде ломался:
# нет TTY, kubeconfig root, v3 требует SERVER у argocd login.
# Application CR создаёт тот же эффект, без сессии CLI.
# ============================================

set -e
trap 'echo "[GitOps] ERROR line $LINENO exit $?"' ERR

NAMESPACE="argocd"
REPO_URL="https://github.com/brooh2121/argocd-apps.git"
APP_NAME="nginx"
APP_PATH="."

echo "[GitOps] Setting up GitOps cycle..."

echo "[GitOps] Waiting for ArgoCD components..."
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-repo-server --timeout=180s
kubectl wait -n "$NAMESPACE" --for=condition=available deployment/argocd-server --timeout=180s
kubectl rollout status statefulset/argocd-application-controller -n "$NAMESPACE" --timeout=180s

echo "[GitOps] Applying Application $APP_NAME..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    path: ${APP_PATH}
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy: {}
EOF

echo "[GitOps] Triggering one-shot sync..."
kubectl -n "$NAMESPACE" patch application "$APP_NAME" --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
  || true

SYNC=""
for i in $(seq 1 36); do
    SYNC=$(kubectl -n "$NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    HEALTH=$(kubectl -n "$NAMESPACE" get application "$APP_NAME" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
    echo "  sync=${SYNC:-none} health=${HEALTH:-none} (attempt $i)"
    if [ "$SYNC" = "Synced" ] || [ "$SYNC" = "OutOfSync" ]; then
        break
    fi
    sleep 5
done

kubectl -n "$NAMESPACE" get application "$APP_NAME"

LB_IP=$(kubectl get svc argocd-server -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

echo ""
echo "=== GitOps Setup Complete ==="
echo "Application : $APP_NAME"
echo "Repository  : $REPO_URL"
if [ -n "$LB_IP" ]; then
    echo "ArgoCD UI   : https://${LB_IP}"
fi
echo "=================================="
