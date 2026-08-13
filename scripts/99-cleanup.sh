#!/bin/bash
# Скрипт для полной очистки системы
# Автор: brooh2121

set -e

# Определяем, подключён ли терминал
if [ -t 1 ]; then
    # Цвета только для интерактивного режима
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    GREEN=''; RED=''; YELLOW=''; NC=''
fi

# Функция для красивого вывода
log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success "Начинаем полную чистку системы..."

# 1. Принудительно останавливаем и удаляем VM в Multipass
log_info "Останавливаем и удаляем VM (с --force)..."
multipass stop --all --force 2>/dev/null || true
multipass delete --all 2>/dev/null || true
multipass purge 2>/dev/null || true
log_success "VM удалены"

# 2. Очищаем локальные папки
log_info "Удаляем локальные конфиги..."
rm -rf ~/.kube ~/runner-data ~/argocd-* ~/gitea-* 2>/dev/null || true
log_success "Локальные конфиги удалены"

# 3. Чистим Docker
log_info "Чистим Docker (если установлен)..."
docker system prune -af 2>/dev/null || true
log_success "Docker очищен"

# 4. Очищаем кэш apt
log_info "Чистим кэш пакетов..."
sudo apt-get clean 2>/dev/null || true
sudo apt-get autoclean 2>/dev/null || true
log_success "Кэш пакетов очищен"

log_success "Чистка завершена! Система готова к новому развертыванию."