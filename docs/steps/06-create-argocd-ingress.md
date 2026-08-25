# Шаг 6. Ingress для ArgoCD

Скрипт: `scripts/06-create-argocd-ingress.sh`

Манифест: `manifests/argocd-ingress.yaml`

## Назначение

Открыть UI `ArgoCD` по имени `https://argocd.local` через `ingress-nginx`.

## Предварительные условия

- выполнен шаг 4: `ArgoCD` установлен в namespace `argocd`;
- выполнен шаг 5: `ingress-nginx` установлен и получил IP от `MetalLB`;
- файл `manifests/argocd-ingress.yaml` есть в репозитории;
- скрипт запускается из корня репозитория, потому что путь к манифесту относительный.

## Что делает скрипт

1. Проверяет наличие `manifests/argocd-ingress.yaml`.
2. Копирует манифест на мастер-ноду через `multipass transfer`.
3. Применяет Ingress в кластере.
4. Читает IP сервиса `ingress-nginx-controller`.
5. Удаляет временный файл на мастер-ноде.
6. Печатает URL `https://argocd.local` и строку для файла `hosts`.

## Содержимое манифеста

Ingress `argocd-ingress` создается в namespace `argocd`:
- класс: `nginx`;
- хост: `argocd.local`;
- путь: `/`;
- backend: сервис `argocd-server`, порт `443`.

Аннотации:
- `nginx.ingress.kubernetes.io/backend-protocol: HTTPS` - контроллер ходит к `argocd-server` по HTTPS;
- `nginx.ingress.kubernetes.io/ssl-redirect: "false"` - принудительный редирект на TLS на стороне Ingress отключен.

Сертификат для `argocd.local` на этом этапе не выпускается. Браузер может показать предупреждение о сертификате `ArgoCD`.

## Настройка доступа с Windows

После успешного запуска добавьте в файл:

`C:\Windows\System32\drivers\etc\hosts`

строку вида:

```
<INGRESS_IP> argocd.local
```

`<INGRESS_IP>` берется из вывода скрипта. Файл `hosts` нужно править с правами администратора.

После этого UI открывается по адресу `https://argocd.local`. Логин `admin`, пароль - из секрета `argocd-initial-admin-secret` (его печатает шаг 4).

## Важные замечания

- шаг 4 по-прежнему публикует `argocd-server` как `LoadBalancer`, поэтому UI доступен и по IP сервиса, и по Ingress;
- имя `argocd.local` существует только после записи в `hosts`;
- манифест не содержит TLS-секцию Ingress, HTTPS на входе зависит от настроек контроллера и backend.
