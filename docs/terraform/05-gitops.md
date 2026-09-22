# OpenTofu: GitOps через ArgoCD CLI

Скрипт: `scripts-tofu/setup-gitops.sh`

Ресурс: `null_resource.setup_gitops` в `opentofu/main.tf`

## Назначение

После установки ArgoCD подключить репозиторий `argocd-apps` и создать Application `nginx`.

## Ошибка dial tcp ...:8081 i/o timeout

Это не таймаут GitHub. Порт `8081` - gRPC `argocd-repo-server`. Адрес вида `10.100.x.x` - ClusterIP сервиса в кластере.

`argocd app sync` просит application-controller сходить в repo-server по ClusterIP. Если kube-proxy не прокидывает Service (нет `br_netfilter` / `ip_forward`), пакеты зависают, CLI получает `ComparisonError`.

В `scripts-tofu/install-k8s-node.sh` эти sysctl теперь выставляются, как в bash-шаге `scripts/01-install-k8s.sh`. На уже поднятых VM нужно либо прогнать `tofu apply` (сменится `script_sha` ноды), либо вручную на каждой ноде:

```
sudo modprobe overlay br_netfilter
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.ipv4.ip_forward=1
```

Проверка, что ClusterIP живой:

```
multipass exec k8s-master -- kubectl get svc -n argocd argocd-repo-server
multipass exec k8s-master -- kubectl get endpoints -n argocd argocd-repo-server
```

## Что делает скрипт

1. Ставит `argocd` CLI в `/usr/local/bin`.
2. Ждет Available у `argocd-repo-server`.
3. Логинится на LoadBalancer IP `argocd-server:443`.
4. Добавляет GitHub-репозиторий и Application `nginx`.
5. Делает `argocd app sync`.

Запускается от `ubuntu`, не через `sudo`.
