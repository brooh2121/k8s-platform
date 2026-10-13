# OpenTofu: Actions Runner Controller (ARC)

Скрипт: `scripts-tofu/install-arc.sh`

Ресурс: `null_resource.install_arc` в `opentofu/main.tf`

PAT лежит локально в `~/.arc-token` (WSL home, не в Git). Tofu копирует его на master как `/tmp/arc-token.txt`.

## Назначение

Поставить GitHub Actions Runner Controller (charts `gha-runner-scale-set-controller` и `gha-runner-scale-set`) и зарегистрировать scale set на организацию `https://github.com/brooh2121`.

Это не старый `actions-runner-controller` с cert-manager. Новый стек: controller в `arc-systems`, раннеры в `arc-runners`.

## Почему падал apply

Helm release называется `arc`. Deployment контроллера в актуальном chart: **`arc-gha-rs-controller`**.

Скрипт ждал `arc-gha-runner-scale-set-controller` - такого объекта нет, `kubectl rollout` давал NotFound, хотя Helm и PAT уже были на месте.

Имя теперь берётся из `kubectl get deploy -n arc-systems`.

## PAT

Файл `~/.arc-token` на машине, откуда идёт `tofu apply` (WSL). Нужны права на создание self-hosted runners в org/repo.

Org URL `https://github.com/brooh2121` требует org-level PAT (или classic token с `admin:org` / fine-grained: Administration на org runners). Для одного репозитория URL был бы `https://github.com/brooh2121/k8s-platform`.

## Проверка

```
multipass exec k8s-master -- kubectl get deploy,pods -n arc-systems
multipass exec k8s-master -- kubectl get autoscalingrunnerset,pods -n arc-runners
```

Ожидание: Deployment `arc-gha-rs-controller` Available. В GitHub: Settings -> Actions -> Runners, группа `arc-runner-set`.

Образы и charts тянутся с `ghcr.io`. Если Helm падает на pull - тот же класс geo-block, что у HashiCorp Helm repo.
