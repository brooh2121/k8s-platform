#!/bin/bash
# ============================================
# Шаг 2: Установка сетевого плагина Flannel
# ============================================
# Описание: Установка Flannel для сети Pod'ов.
# Автор: brooh2121
# Дата: 2026-08-18
# ============================================

set -e

VM_NAME="k8s-master"

echo "[STEP 2] Installing Flannel network plugin..."

# Применяем манифест Flannel (можно использовать latest)
FLANNEL_URL="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
# Или зафиксированная версия:
# FLANNEL_URL="https://raw.githubusercontent.com/flannel-io/flannel/v0.26.2/Documentation/kube-flannel.yml"

echo "Applying Flannel manifest from $FLANNEL_URL"
multipass exec $VM_NAME -- kubectl apply -f "$FLANNEL_URL"

echo "Waiting for Flannel pods to become Ready..."

# Ждём до 2 минут, пока все поды Flannel будут Ready
for i in {1..24}; do
    NOT_READY=$(multipass exec $VM_NAME -- kubectl get pods -n kube-flannel \
        --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo 1)

    if [ "$NOT_READY" -eq 0 ]; then
        echo "All Flannel pods are Ready."
        break
    fi

    echo "  Attempt $i/24: still waiting... ($NOT_READY pods not ready)"
    sleep 5
done

# Финальная проверка
echo ""
echo "=== Flannel pods status ==="
multipass exec $VM_NAME -- kubectl get pods -n kube-flannel -o wide

echo ""
echo "=== Nodes status ==="
multipass exec $VM_NAME -- kubectl get nodes -o wide

echo ""
echo "[STEP 2] Flannel installation completed."