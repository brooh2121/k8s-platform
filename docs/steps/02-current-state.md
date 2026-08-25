# Текущее состояние проекта

## Что уже реализовано

На текущий момент в проекте выполнены базовые шаги подготовки кластера Kubernetes и первые платформенные компоненты: `ArgoCD` и Ingress.

### Шаг 0. Создание виртуальных машин

Скрипт `scripts/00-create-vms.sh` создает три виртуальные машины в `Multipass`:
- `k8s-master`;
- `k8s-worker1`;
- `k8s-worker2`.

Для каждой виртуальной машины задаются параметры CPU, памяти, диска и образа Ubuntu.

### Шаг 1. Установка Kubernetes

Скрипт `scripts/01-install-k8s.sh` выполняет:
- отключение swap;
- установку системных зависимостей;
- установку `docker-ce`, `docker-ce-cli`, `containerd.io`;
- установку `kubeadm`, `kubelet`, `kubectl`;
- настройку модулей ядра и параметров `sysctl`;
- настройку `containerd`;
- инициализацию control plane на master-ноде;
- получение команды подключения worker-нод;
- присоединение worker-нод к кластеру.

### Шаг 2. Установка Flannel

Скрипт `scripts/02-install-flannel.sh` применяет манифест `Flannel` и ждет, пока сетевые pod'ы перейдут в состояние готовности.

На этом этапе кластер получает внутреннюю Pod-сеть.

### Шаг 3. Установка MetalLB

Скрипт `scripts/03-install-metallb.sh` выполняет:
- установку `MetalLB`;
- ожидание запуска pod'ов `metallb-system`;
- определение подсети master-ноды;
- создание `IPAddressPool`;
- создание `L2Advertisement`.

На этом этапе сервисы типа `LoadBalancer` получают возможность получать внешние IP-адреса внутри локальной сети стенда.

### Шаг 4. Установка ArgoCD

Скрипт `scripts/04-install-argocd.sh` выполняет:
- создание namespace `argocd`;
- загрузку официального манифеста `ArgoCD`;
- замену образа Redis на `redis:7.2-alpine`;
- установку через Server-Side Apply;
- перевод сервиса `argocd-server` в тип `LoadBalancer`;
- вывод IP и начального пароля администратора.

Подробности: `docs/steps/04-install-argocd.md`.

### Шаг 5. Установка NGINX Ingress Controller

Скрипт `scripts/05-install-ingress-controller.sh` выполняет:
- установку `ingress-nginx` версии `controller-v1.12.1`;
- ожидание запуска pod'ов в namespace `ingress-nginx`;
- вывод внешнего IP сервиса контроллера.

Подробности: `docs/steps/05-install-ingress-controller.md`.

### Шаг 6. Ingress для ArgoCD

Скрипт `scripts/06-create-argocd-ingress.sh` применяет манифест `manifests/argocd-ingress.yaml` и печатает строку для файла `hosts`. После этого UI `ArgoCD` доступен по адресу `https://argocd.local`.

Подробности: `docs/steps/06-create-argocd-ingress.md`.

## Что важно помнить

- проект пока ориентирован на локальный стенд и учебный сценарий;
- многие параметры в скриптах пока заданы напрямую;
- запуск выполняется по шагам, а не через единый orchestration-пайплайн;
- часть конфигурации генерируется динамически во время выполнения скриптов.

## Текущая точка остановки

На данный момент выполнены установка `ArgoCD`, Ingress-контроллера и Ingress для UI. `ArgoCD` пока только установлен: репозитории, Applications и CI еще не подключены.

Следующий блок работы - преднастройка `ArgoCD` и связка с GitLab CI/CD (GitLab Actions). После этого - `RBAC` и `HashiCorp Vault`.
