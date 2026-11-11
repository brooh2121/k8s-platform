#!/bin/bash
# ============================================
# Установка Flannel (сетевой плагин)
# ============================================
# Параметры: нет (выполняется на мастере)
# ============================================

set -e

# Манифест upstream тянет docker.io/flannel/*; с Docker Hub pull часто стоит минутами.
# Те же теги публикуются на ghcr.io/flannel-io/.
echo "[Flannel] Downloading manifest v0.25.6 and retargeting images to ghcr.io..."
curl -fsSL -o /tmp/kube-flannel.yml \
  https://raw.githubusercontent.com/flannel-io/flannel/v0.25.6/Documentation/kube-flannel.yml
sed -i 's|docker.io/flannel/|ghcr.io/flannel-io/|g' /tmp/kube-flannel.yml
kubectl apply -f /tmp/kube-flannel.yml

# Образы с docker.io (flannel-cni-plugin) на воркерах часто едут минуты.
echo "[Flannel] Waiting for DaemonSet kube-flannel-ds (timeout 10m)..."
kubectl rollout status daemonset/kube-flannel-ds -n kube-flannel --timeout=600s

kubectl get pods -n kube-flannel -o wide
kubectl get nodes