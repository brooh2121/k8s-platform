# OpenTofu: создание VM и установка Kubernetes

Каталог: `opentofu/`

Скрипты на ноде:
- `scripts-tofu/install-k8s-node.sh` - kubeadm master/worker;
- `scripts-tofu/install-flannel.sh` - CNI Flannel на master;
- `scripts-tofu/install-metallb.sh` - MetalLB и IP-пул;
- `scripts-tofu/install-ingress.sh` - NGINX Ingress Controller;
- `scripts-tofu/install-argocd.sh` - ArgoCD в namespace `argocd`.

Документация bash-пути (шаги `scripts/00` и далее) лежит в `docs/steps/`. Этот файл описывает только IaC-путь.

## Назначение

Это второй способ поднять базовый кластер: не через пошаговые `scripts/00` и `scripts/01`, а через OpenTofu. Стек создает три VM в `Multipass`, ставит Kubernetes, `Flannel`, `MetalLB`, Ingress и `ArgoCD`.

## Состав

Корневой модуль `opentofu/`:
- `main.tf` - провайдеры, VM, Kubernetes, Flannel, MetalLB, Ingress, ArgoCD;
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
4. `null_resource.install_flannel` копирует и запускает `scripts-tofu/install-flannel.sh` на master;
5. `null_resource.install_metallb` ставит MetalLB;
6. `null_resource.install_ingress` ставит NGINX Ingress Controller;
7. `null_resource.install_argocd` ставит ArgoCD;
8. модули worker-нод ставят Kubernetes и присоединяются к кластеру.

Flannel зависит только от master. ArgoCD: `docs/terraform/04-argocd.md`. Flannel: `docs/terraform/03-flannel.md`.

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
- кладет kubeconfig и для `ubuntu` (`/home/ubuntu/.kube/config`), и для `root` (`/root/.kube/config`). Скрипт часто идет от root через `sudo`, а `multipass exec` по умолчанию работает как `ubuntu`;
- пишет join-команду в `/tmp/join-command`.

На worker:
- по SSH забирает `/tmp/join-command` с master (ключ `id_rsa_tofu`);
- выполняет `kubeadm join`.

## Windows Git + WSL apply

Git-рабочая копия лежит на Windows, `tofu apply` запускается в WSL. Это два разных мира путей:

- Windows: `E:\git_works\k8s-platform\k8s-platform\...`
- WSL: `/mnt/e/git_works/k8s-platform/k8s-platform/...`
- home в WSL: `/home/<user>/...` - это уже не git-копия

Поэтому путь `/home/dismas/k8s-platform/scripts-tofu/install-k8s-node.sh` не работает: репозиторий там не лежит. Относительный `source` тоже ломается, если provisioner резолвит путь не так, как WSL видит `/mnt/e`.

Как сделано сейчас:
- корень репозитория считается через `abspath("${path.root}/../scripts-tofu/install-k8s-node.sh")`;
- скрипт читается функцией `file()` и передается в VM через `provisioner "file" { content = ... }`;
- после копирования с файла снимается CR (`sed`), потому что Git на Windows часто хранит `.sh` как CRLF, а bash на Ubuntu от этого падает.

`tofu apply` нужно запускать из WSL в каталоге Windows-checkout, например:

```
cd /mnt/e/git_works/k8s-platform/k8s-platform/opentofu
tofu apply
```

Ключи `id_rsa_tofu` должны быть в **WSL home** (`~/.ssh/`), потому что `~` раскрывается уже в Linux. Ключ из `C:\Users\...\.ssh` WSL сам не подхватит, пока его туда не скопировать или не пробросить через agent.

## Предварительные условия

- установлены `OpenTofu` и `Multipass`, команда `multipass` доступна из WSL;
- есть ключи `~/.ssh/id_rsa_tofu` и `~/.ssh/id_rsa_tofu.pub` именно в WSL;
- SSH-agent в WSL знает приватный ключ (`agent = true`).

## Результат

После успешного apply:
- три VM в `Multipass`;
- control plane инициализирован, worker-ноды присоединены;
- установлены `Flannel`, `MetalLB`, Ingress и `ArgoCD`;
- `multipass exec k8s-master -- kubectl get ns argocd` должен показать namespace;
- в `opentofu/outputs` доступны IP-адреса;
- файл `opentofu/join-command.txt` содержит команду join (если master отработал).

Проверка:

```
multipass exec k8s-master -- kubectl get nodes
multipass exec k8s-master -- kubectl get pods -n kube-flannel
multipass exec k8s-master -- kubectl get ns argocd
```

## Важные замечания

- если скрипт не копируется на master, в логе apply должен быть абсолютный WSL-путь вида `/mnt/e/.../scripts-tofu/install-k8s-node.sh`, а не `/home/...` и не `E:\...`;
- CPU, память и диск в корневом `main.tf` пока захардкожены, корневой `variables.tf` пустой;
- у модулей нет полного набора `main.tf` + `variables.tf` + `outputs.tf` по правилу HCL: часть переменных и output лежит в `main.tf`;
- приватный ключ копируется на VM, это учебный прием, ключ в git коммитить нельзя;
- `join-command.txt` содержит секрет кластера, в репозиторий его класть не нужно;
- каталог `terraform/` - более ранний эксперимент, только создание VM без установки Kubernetes. См. `docs/terraform/02-terraform-experiment.md`.
