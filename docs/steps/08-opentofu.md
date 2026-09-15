# OpenTofu: создание VM и установка Kubernetes

Каталог: `opentofu/`

Скрипт на ноде: `scripts-tofu/install-k8s-node.sh`

## Назначение

Это второй способ поднять базовый кластер: не через пошаговые `scripts/00` и `scripts/01`, а через OpenTofu. Стек создает три VM в `Multipass` и ставит Kubernetes на master и worker-ноды по SSH.

Bash-скрипты в `scripts/` при этом остаются основным учебным путем для шагов 2 и далее (`Flannel`, `MetalLB`, `ArgoCD`).

## Состав

Корневой модуль `opentofu/`:
- `main.tf` - провайдеры, VM, установка Kubernetes, копирование join-команды;
- `outputs.tf` - IP master и worker-нод;
- `variables.tf` - пока пустой, параметры заданы в `main.tf`.

Модуль `opentofu/modules/vm`:
- создает `multipass_instance`;
- пробрасывает публичный ключ `~/.ssh/id_rsa_tofu.pub` через cloud-init;
- отдает IPv4 машины.

Модуль `opentofu/modules/k8s-node`:
- копирует на VM скрипт `scripts-tofu/install-k8s-node.sh`;
- копирует приватный ключ `~/.ssh/id_rsa_tofu`;
- запускает скрипт по SSH (`user = ubuntu`, `agent = true`).

## Порядок применения

Запускать из каталога `opentofu/`:

```
tofu init
tofu apply
```

Порядок ресурсов:
1. VM `k8s-master`, `k8s-worker1`, `k8s-worker2`;
2. модуль `k8s_master` ставит Kubernetes на master;
3. `null_resource.master_ready` копирует `/tmp/join-command` с master в `opentofu/join-command.txt`;
4. модули worker-нод ставят Kubernetes и должны присоединиться к кластеру.

## Скрипт install-k8s-node.sh

Скрипт выполняется уже внутри VM.

Аргументы:
- `$1` - тип ноды: `master` или `worker`;
- `$2` - IP master-ноды (для worker).

На любой ноде:
- ставит Docker через `get.docker.com`;
- ставит `kubeadm`, `kubelet`, `kubectl` из зеркала Kubernetes v1.36;
- включает `SystemdCgroup` в `containerd`.

На master:
- `kubeadm init` с Pod CIDR `10.244.0.0/16` и реестром `registry.aliyuncs.com/google_containers`;
- настраивает `kubectl`;
- пишет join-команду в `/tmp/join-command`.

На worker:
- должен выполнить join-команду. В текущей версии скрипта переменная `JOIN_COMMAND` не заполняется, это известный пробел.

## Предварительные условия

- установлены `OpenTofu` и `Multipass`;
- есть ключи `~/.ssh/id_rsa_tofu` и `~/.ssh/id_rsa_tofu.pub`;
- SSH-agent знает приватный ключ (`agent = true`);
- путь к скрипту в модуле `k8s-node` сейчас абсолютный: `/home/dismas/k8s-platform/scripts-tofu/install-k8s-node.sh`. На другой машине apply не найдет файл, пока путь не параметризуют.

## Результат

После успешного apply:
- три VM в `Multipass`;
- control plane инициализирован;
- в `opentofu/outputs` доступны IP-адреса;
- файл `opentofu/join-command.txt` содержит команду join (если master отработал).

Сеть Pod (`Flannel`) и `MetalLB` этим стеком не ставятся. Их по-прежнему накатывают скрипты `scripts/02` и `scripts/03`.

## Важные замечания

- CPU, память и диск в корневом `main.tf` пока захардкожены, корневой `variables.tf` пустой;
- у модулей нет полного набора `main.tf` + `variables.tf` + `outputs.tf` по правилу HCL: часть переменных и output лежит в `main.tf`;
- приватный ключ копируется на VM, это учебный прием, ключ в git коммитить нельзя;
- `join-command.txt` содержит секрет кластера, в репозиторий его класть не нужно;
- каталог `terraform/` - более ранний эксперимент, только создание VM без установки Kubernetes. См. `docs/steps/09-terraform-experiment.md`.
