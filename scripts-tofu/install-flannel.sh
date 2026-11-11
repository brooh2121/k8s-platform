#!/bin/bash
# ============================================
# Установка Flannel (сетевой плагин)
# ============================================
# Параметры: нет (выполняется на мастере)
# ============================================

set -e

# v0.25.6 тянет docker.io; sed на ghcr.io ломает CNI-плагин: тег
# flannel-cni-plugin:v1.5.1-flannel2 на GHCR нет, kubelet уходит в BackOff.
# v0.26.7 уже указывает на ghcr.io/flannel-io (flannel + cni-plugin v1.6.2-flannel1).
echo "[Flannel] Applying official kube-flannel.yml v0.26.7 (images on ghcr.io)..."
curl -fsSL -o /tmp/kube-flannel.yml \
  https://raw.githubusercontent.com/flannel-io/flannel/v0.26.7/Documentation/kube-flannel.yml
kubectl apply -f /tmp/kube-flannel.yml

# Образы с docker.io (flannel-cni-plugin) на воркерах часто едут минуты.
echo "[Flannel] Waiting for DaemonSet kube-flannel-ds (timeout 10m)..."
kubectl rollout status daemonset/kube-flannel-ds -n kube-flannel --timeout=600s

kubectl get pods -n kube-flannel -o wide
kubectl get nodes