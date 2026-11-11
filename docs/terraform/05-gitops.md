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

1. Ждёт Available у `argocd-repo-server`, `argocd-server` и application-controller.
2. Применяет CR `Application` `nginx` через `kubectl` (без `argocd login`).
3. Один раз патчит `operation.sync`.

`argocd login --port-forward` в CLI v3 требует адрес SERVER; `--core` писал kubeconfig и падал на `config.lock`. Из-за `exit 1` tofu не показывал тело ошибки. Worker join тут ни при чём: в логе `k8s_worker2` уже Creation complete, падает следующий ресурс.

Повторный join worker уже пропускается, если есть `/etc/kubernetes/kubelet.conf`. Падение GitOps **не** повод делать `tofu destroy`.

Запускается от `ubuntu`, не через `sudo`.

## LoadBalancer IP и GitOps

`setup-gitops` не зависит от External IP. CLI с master ходит через port-forward.

`kubectl config set-context` на этом стенде падает: `/home/ubuntu/.kube` создаётся от root при `kubeadm init`, `config.lock` ubuntu записать не может. Из-за этого GitOps мог выйти с кодом 1, а ARC всё равно ставился (`depends_on` только Ingress).

`install-k8s-node.sh` теперь делает `chown -R ubuntu:ubuntu` на каталог `.kube`.

Если UI/Ingress в `<pending>`, а поды `metallb-system` Running - смотрите пул, не длину цикла ожидания:

```
multipass exec k8s-master -- kubectl get ipaddresspools,l2advertisements -n metallb-system
multipass exec k8s-master -- kubectl get svc -n argocd argocd-server
```

Пустой пул: `install-metallb.sh` применил манифест MetalLB, а `IPAddressPool` не прошёл вебхук (ошибка глоталась, скрипт выходил 0). Скрипт теперь берёт `InternalIP` control-plane (не `hostname -I`) и падает, если пул не создался.
