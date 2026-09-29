# OpenTofu: установка HashiCorp Vault

Скрипт: `scripts-tofu/install-vault.sh`

Манифест: `manifests/vault-ingress.yaml`

Ресурс: `null_resource.install_vault` в `opentofu/main.tf`

## Назначение

Поставить Vault в namespace `vault` в dev-режиме (учебный стенд) и открыть UI по `vault.local` через Ingress.

## Helm на master

На kubeadm-нодах Helm из коробки нет. Скрипт ставит бинарник `v3.16.4` в `/usr/local/bin/helm`, если `helm` не найден.

Проверка:

```
multipass exec k8s-master -- helm version
```

Раньше apply падал на `helm: command not found`. Terraform все равно пытался применить Ingress, namespace `vault` еще не существовал.

Порядок сейчас:
1. установка Helm при необходимости;
2. создание namespace `vault`;
3. скачивание chart `vault-helm` v0.29.1 с GitHub (не `helm.releases.hashicorp.com` - он часто закрыт по гео);
4. `helm upgrade --install` в dev-режиме, корневой токен `root`;
5. ожидание Running;
6. `kubectl apply` Ingress.

## Доступ

После apply добавьте в Windows `hosts` IP Ingress-контроллера:

```
<INGRESS_IP> vault.local
```

UI: `http://vault.local`, токен `root`. Это только для лаборатории, не для продакшена.
