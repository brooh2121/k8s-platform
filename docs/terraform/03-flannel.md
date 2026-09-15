# OpenTofu: установка Flannel

Скрипт: `scripts-tofu/install-flannel.sh`

Ресурс: `null_resource.install_flannel` в `opentofu/main.tf`

## Назначение

Поставить CNI `Flannel` в кластер, который уже создан OpenTofu. Без этого ноды остаются в `NotReady`.

Это IaC-аналог bash-шага `scripts/02-install-flannel.sh`. Документация bash-пути: `docs/steps/02-current-state.md`.

## Что делает Terraform

`null_resource.install_flannel`:
- ждет `module.k8s_master` (`depends_on`);
- подключается по SSH к master (`ubuntu`, `agent = true`);
- читает скрипт через `file()` и копирует его в `/tmp/install-flannel.sh`;
- снимает CR (`sed`), выставляет `chmod +x`;
- запускает `sudo /tmp/install-flannel.sh`.

Скрипт идет от root, поэтому `kubectl` берет kubeconfig из `/root/.kube/config` (его создает `install-k8s-node.sh` на master).

Worker-модули в `depends_on` не входят. Flannel ставится DaemonSet: если воркеры присоединятся чуть позже, агент поднимется на них сам.

## Что делает скрипт

1. Применяет манифест Flannel версии `v0.25.6`.
2. Ждет 10 секунд.
3. Печатает pod'ы в namespace `kube-flannel`.

Версия зафиксирована, в отличие от bash-скрипта `scripts/02-install-flannel.sh`, который берет `latest`.

## Результат

После apply:
- в кластере есть CNI;
- `kubectl get nodes` со временем должен показать `Ready`;
- в `kube-flannel` должны появиться Running pod'ы.

Проверка:

```
multipass exec k8s-master -- kubectl get nodes
multipass exec k8s-master -- kubectl get pods -n kube-flannel
```

Паузы в 10 секунд может не хватить на первую загрузку образов. Если ноды еще `NotReady`, подождите и повторите `get nodes`.

## Важные замечания

- `MetalLB`, Ingress и `ArgoCD` этим ресурсом не ставятся;
- путь к скрипту задан как `${path.root}/../scripts-tofu/install-flannel.sh`, `tofu apply` запускайте из каталога `opentofu/` в WSL-checkout.
