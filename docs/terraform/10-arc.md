# OpenTofu: Actions Runner Controller (ARC)

Скрипт: `scripts-tofu/install-arc.sh`

Ресурс: `null_resource.install_arc` в `opentofu/main.tf`

PAT лежит локально в `~/.arc-token` (WSL home, не в Git). Tofu копирует его на master как `/tmp/arc-token.txt`.

## Назначение

Поставить GitHub Actions Runner Controller (charts `gha-runner-scale-set-controller` и `gha-runner-scale-set`) и зарегистрировать scale set на репозиторий `https://github.com/brooh2121/github-actions-pipeline`.

Self-hosted runner на весь аккаунт GitHub без org нельзя: нужен URL конкретного репозитория (или org, если это организация).

Это не старый `actions-runner-controller` с cert-manager. Новый стек: controller в `arc-systems`, раннеры в `arc-runners`.

## Почему падал apply

Helm release называется `arc`. Deployment контроллера в актуальном chart: **`arc-gha-rs-controller`**.

Скрипт ждал `arc-gha-runner-scale-set-controller` - такого объекта нет, `kubectl rollout` давал NotFound, хотя Helm и PAT уже были на месте.

Имя теперь берётся из `kubectl get deploy -n arc-systems`.

## PAT

Файл `~/.arc-token` на машине, откуда идёт `tofu apply` (WSL). Нужны права на создание self-hosted runners в org/repo.

`githubConfigUrl` - репозиторий, не пользователь. Helm `--set` пишется `key=value`, не `key: value` (иначе chart-аргумент теряется и `helm upgrade` отвечает "requires 2 arguments").

PAT: classic с `repo` (и право на self-hosted runners) или fine-grained на этот репозиторий. После смены URL в скрипте `script_sha` меняется, `tofu apply` заново гоняет `install_arc`.

## Проверка

```
multipass exec k8s-master -- kubectl get deploy,pods -n arc-systems
multipass exec k8s-master -- kubectl get autoscalingrunnerset,pods -n arc-runners
```

Ожидание: Deployment `arc-gha-rs-controller` Available. В GitHub: Settings -> Actions -> Runners, группа `arc-runner-set`.

Образы и charts тянутся с `ghcr.io`. Если Helm падает на pull - тот же класс geo-block, что у HashiCorp Helm repo.
