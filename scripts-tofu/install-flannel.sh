#!/bin/bash
# ============================================
# Установка Flannel (сетевой плагин)
# ============================================
# Параметры: нет (выполняется на мастере)
# ============================================

set -e

# Устанавливаем Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.25.6/Documentation/kube-flannel.yml

# Ждём, пока поды Flannel запустятся
echo "Waiting for Flannel pods to be ready..."
sleep 10

# Проверяем статус
kubectl get pods -n kube-flannel