# k8s-platform

Учебный репозиторий для поэтапного развертывания и настройки локального Kubernetes-кластера на базе Multipass.

## Цель проекта

Цель проекта - руками пройти основные этапы создания кластера Kubernetes и дальнейшей настройки платформенных компонентов. Репозиторий используется как учебный стенд и база для практики.

На текущем этапе в проекте уже реализованы:
- создание виртуальных машин для control plane и worker-нод;
- установка Kubernetes через `kubeadm`;
- настройка сетевого плагина `Flannel`;
- установка и базовая настройка `MetalLB`;
- установка `ArgoCD`;
- установка `NGINX Ingress Controller`;
- публикация UI `ArgoCD` через Ingress на `argocd.local`.

Следующие этапы развития:
- преднастройка `ArgoCD` и связка с GitLab CI/CD (GitLab Actions);
- настройка `RBAC`;
- установка `HashiCorp Vault`;
- автоматизация всего процесса в одном пайплайне.

## Структура репозитория

- `scripts/` - пошаговые bash-скрипты развертывания и обслуживания;
- `manifests/` - Kubernetes-манифесты;
- `docs/steps/` - документация по текущему состоянию, шагам и roadmap проекта.

## Текущие шаги развертывания

1. `scripts/00-create-vms.sh` - создание виртуальных машин в `Multipass`.
2. `scripts/01-install-k8s.sh` - установка Kubernetes и инициализация кластера.
3. `scripts/02-install-flannel.sh` - установка сетевого плагина `Flannel`.
4. `scripts/03-install-metallb.sh` - установка `MetalLB` и создание IP-пула.
5. `scripts/04-install-argocd.sh` - установка `ArgoCD`.
6. `scripts/05-install-ingress-controller.sh` - установка `NGINX Ingress Controller`.
7. `scripts/06-create-argocd-ingress.sh` - Ingress для UI `ArgoCD`.
8. `scripts/99-cleanup.sh` - очистка локального стенда.

## Документация

- `docs/steps/01-project-overview.md` - обзор проекта и текущего состояния;
- `docs/steps/02-current-state.md` - описание уже выполненных шагов;
- `docs/steps/03-roadmap.md` - roadmap следующих этапов настройки кластера;
- `docs/steps/04-install-argocd.md` - установка `ArgoCD`;
- `docs/steps/05-install-ingress-controller.md` - установка Ingress-контроллера;
- `docs/steps/06-create-argocd-ingress.md` - Ingress для `ArgoCD`.