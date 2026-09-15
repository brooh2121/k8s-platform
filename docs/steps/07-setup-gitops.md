# Шаг 7. Настройка GitOps через ArgoCD CLI

Скрипт: `scripts/07-setup-gitops.sh`

## Назначение

Преднастроить `ArgoCD` через CLI: установить клиент на master-ноду, подключить Git-репозиторий с манифестами и создать первое Application. После этого desired state приложений живет в Git, а `ArgoCD` применяет его в кластер.

## Предварительные условия

- выполнен шаг 4: `ArgoCD` установлен, секрет `argocd-initial-admin-secret` существует;
- сервис `argocd-server` доступен (предпочтительно через `LoadBalancer` после шага 4);
- на хосте доступен `multipass`;
- мастер-нода называется `k8s-master`;
- репозиторий `https://github.com/brooh2121/argocd-apps.git` доступен для чтения с master-ноды.

Шаги 5 и 6 (Ingress) для этого скрипта не обязательны: CLI ходит к `argocd-server` по IP `LoadBalancer` или через NodePort.

## Что делает скрипт

1. Устанавливает `argocd` CLI на `k8s-master`, если его еще нет. Бинарник берется из `latest` релиза Argo CD.
2. Читает пароль `admin` из секрета `argocd-initial-admin-secret`.
3. Определяет адрес API-сервера `ArgoCD`:
   - сначала External IP сервиса `argocd-server` и порт `443`;
   - если IP нет, fallback: InternalIP первой ноды и NodePort HTTPS.
4. Выполняет `argocd login` с флагами `--insecure` и `--grpc-web`.
5. Добавляет репозиторий `https://github.com/brooh2121/argocd-apps.git` (`--insecure`). Повторный запуск не падает, если репозиторий уже добавлен.
6. Создает Application `nginx`:
   - путь в репозитории: `.`;
   - целевой кластер: `https://kubernetes.default.svc`;
   - namespace: `default`;
   - политика синхронизации: `none` (автосинхронизация выключена);
   - флаг `--upsert` делает создание идемпотентным.
7. Один раз синхронизирует приложение: `argocd app sync nginx`.
8. Печатает статус Application.

## Результат

В `ArgoCD` появляются:
- подключенный Git-репозиторий `argocd-apps`;
- Application `nginx`, синхронизированное вручную один раз.

Скрипт печатает имя приложения, URL репозитория и адрес `ArgoCD`, по которому выполнялся login.

Проверка в UI: `https://argocd.local` (после шага 6 и записи в `hosts`) или IP `LoadBalancer` из шага 4. Приложение должно быть видно в списке Applications.

## Важные замечания

- репозиторий приложений сейчас на GitHub, не в GitLab;
- `sync-policy none` означает, что новые коммиты сами в кластер не попадут, нужна ручная синхронизация в UI или через CLI;
- CLI ставится с `releases/latest`, версия клиента не зафиксирована;
- login идет с `--insecure`, потому что на этом этапе нет доверенного TLS-сертификата;
- GitLab CI/CD на этом шаге не настраивается.
