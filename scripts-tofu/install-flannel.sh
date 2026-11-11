#!/bin/bash
# ============================================
# Установка Flannel (сетевой плагин)
# ============================================
# Параметры: нет (выполняется на мастере)
# ============================================

set -e

# Устанавливаем Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.25.6/Documentation/kube-flannel.yml

# Образы с docker.io (flannel-cni-plugin) на воркерах часто едут минуты.
echo "[Flannel] Waiting for DaemonSet kube-flannel-ds (timeout 10m)..."
kubectl rollout status daemonset/kube-flannel-ds -n kube-flannel --timeout=600s

kubectl get pods -n kube-flannel -o wide
kubectl get nodes