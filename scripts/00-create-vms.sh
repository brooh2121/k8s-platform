#!/bin/bash
# Скрипт для создания VM в Multipass (временный, пока не перейдём на Vagrant)
# Этот скрипт будет заменён на Vagrantfile в папке infra/

set -e

echo "=== Создание VM для кластера Kubernetes (Multipass) ==="

VM_CPU=2
VM_MEMORY=2G
VM_DISK=10G
VM_IMAGE=22.04

echo "Удаление старых VM (если они есть)..."
multipass delete k8s-master k8s-worker1 k8s-worker2 --purge 2>/dev/null || true

echo "Создание мастер-ноды..."
multipass launch --name k8s-master --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE

echo "Создание воркер-нод..."
multipass launch --name k8s-worker1 --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE
multipass launch --name k8s-worker2 --cpus $VM_CPU --memory $VM_MEMORY --disk $VM_DISK $VM_IMAGE

echo "=== Список VM ==="
multipass list

echo "✅ VM созданы успешно!"