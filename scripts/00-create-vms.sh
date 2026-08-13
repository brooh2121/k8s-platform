#!/bin/bash
# ============================================
# Шаг 0: Создание виртуальных машин в Multipass
# ============================================
# Описание: Этот скрипт создаёт три VM (master + 2 workers)
# для кластера Kubernetes.
# Автор: brooh2121
# Дата: 2026-08-13
# ============================================

set -e

echo "[STEP 0] Starting creation of virtual machines..."

# Параметры VM
VM_CPU=2
VM_MEMORY=2G
VM_DISK=10G
VM_IMAGE=22.04

echo "   - Platform: Multipass"
echo "   - Number of VMs: 3 (1 master, 2 workers)"
echo "   - Resources: CPU=$VM_CPU, RAM=$VM_MEMORY, DISK=$VM_DISK"

# Удаляем старые VM (если есть)
echo "Cleaning up old VMs (if any)..."
multipass delete k8s-master k8s-worker1 k8s-worker2 --purge 2>/dev/null || true

# Создаём мастер-ноду
echo "Creating master node (k8s-master)..."
multipass launch --name k8s-master --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE

# Создаём воркер-ноды
echo "Creating worker node 1 (k8s-worker1)..."
multipass launch --name k8s-worker1 --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE

echo "Creating worker node 2 (k8s-worker2)..."
multipass launch --name k8s-worker2 --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE

# Проверяем результат
echo "List of created VMs:"
multipass list

echo "[STEP 0] Virtual machines created successfully!"