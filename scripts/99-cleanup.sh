#!/bin/bash
# Скрипт для полной очистки системы от артефактов нашего кластера

set -e

echo "🧹 Начинаем полную чистку системы..."

# 1. Удаляем VM в Multipass
echo "1. Удаляем VM..."
multipass stop --all --force 2>/dev/null || true
multipass delete --all 2>/dev/null || true
multipass purge 2>/dev/null || true

# 2. Очищаем локальные папки (если они есть)
echo "2. Удаляем локальные конфиги..."
rm -rf ~/.kube
rm -rf ~/runner-data
rm -rf ~/argocd-*
rm -rf ~/gitea-*

# 3. Чистим Docker (если он есть в WSL)
echo "3. Чистим Docker (если установлен)..."
docker system prune -af 2>/dev/null || true

# 4. Очищаем кэш apt
echo "4. Чистим кэш пакетов..."
sudo apt-get clean 2>/dev/null || true
sudo apt-get autoclean 2>/dev/null || true

# 5. Завершаем
echo "✅ Чистка завершена!"
echo "Теперь система готова к новому развертыванию."