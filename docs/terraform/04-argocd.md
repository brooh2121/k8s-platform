# OpenTofu: установка ArgoCD

Скрипт: `scripts-tofu/install-argocd.sh`

Ресурс: `null_resource.install_argocd` в `opentofu/main.tf`

## Назначение

Поставить `ArgoCD` в namespace `argocd` на уже готовый кластер (kubeadm + Flannel + MetalLB + Ingress).

Это IaC-аналог bash-шага `scripts/04-install-argocd.sh`. Скрипт выполняется уже на master, без `multipass exec`.

## Почему пайплайн мог "успешно" не создать namespace

До заполнения `install-argocd.sh` файл был пустым. OpenTofu копировал его в `/tmp/install-argocd.sh` и запускал. Пустой bash-скрипт завершается с кодом 0, apply не падает, ресурсов в кластере нет.

Пустой файл на master: `multipass exec k8s-master -- wc -l /tmp/install-argocd.sh` даст `0`.

После появления содержимого `script_sha` в triggers меняется, следующий `tofu apply` заново прогонит шаг.

## Что делает скрипт

1. Удаляет CRD `applicationsets.argoproj.io`, если он уже есть.
2. Создает namespace `argocd` (`create --dry-run` + `apply`).
3. Скачивает официальный манифест `stable` через `curl` в `/tmp/argocd-install.yaml`.
4. Меняет образ Redis на `redis:7.2-alpine`.
5. Применяет манифест через `kubectl apply --server-side --force-conflicts`.
6. Ждет, пока pod'ы в `argocd` станут `Running`.
7. Переводит сервис `argocd-server` в `LoadBalancer`.
8. Печатает IP от MetalLB и пароль `admin` из `argocd-initial-admin-secret`.

Скрипт идет от пользователя `ubuntu` (kubeconfig `/home/ubuntu/.kube/config`).

## Проверка

```
multipass exec k8s-master -- kubectl get ns argocd
multipass exec k8s-master -- kubectl get pods -n argocd
multipass exec k8s-master -- kubectl get svc -n argocd argocd-server
```

## Важные замечания

- версия Argo CD берется из `stable`, в репозитории не зафиксирована;
- GitOps Application (`scripts/07-setup-gitops.sh`) этим шагом не создается;
- Ingress `argocd.local` из `scripts/06-create-argocd-ingress.sh` пока не входит в OpenTofu.
