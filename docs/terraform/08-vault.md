# OpenTofu: установка HashiCorp Vault

Скрипт: `scripts-tofu/install-vault.sh`

Манифест: `manifests/vault-ingress.yaml`

Ресурс: `null_resource.install_vault` в `opentofu/main.tf`

Зависит от `null_resource.install_ingress`.

Интеграция с Kubernetes (auth, policy, учебный Pod): `docs/terraform/09-vault-injector.md`.

## Назначение

Поставить Vault в namespace `vault` в **dev-режиме** (учебный стенд): данные в памяти, корневой токен `root`, без unseal.

Chart включает **Vault Agent Injector** (`injector.enabled=true`). Это Mutating Admission Webhook: по аннотациям на Pod добавляет sidecar `vault-agent` и кладёт секреты в `/vault/secrets`.

Ingress `vault.local` оставлен как опция. Для лаборатории достаточно CLI:

```
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault status
```

## Helm на master

На kubeadm-нодах Helm из коробки нет. Скрипт ставит бинарник `v3.16.4` в `/usr/local/bin/helm`, если `helm` не найден.

Chart `vault-helm` **v0.29.1** скачивается с GitHub (`hashicorp/vault-helm`), не с `helm.releases.hashicorp.com` (часто geo-block).

Порядок `install-vault.sh`:
1. установка Helm при необходимости;
2. создание namespace `vault`;
3. скачивание и распаковка chart;
4. `helm upgrade --install`: dev-режим, токен `root`, injector включён;
5. ожидание Running;
6. `kubectl apply` Ingress.

## Что должно быть Running

```
multipass exec k8s-master -- kubectl get pods -n vault
```

Ожидание:
- `vault-0` - сервер (StatefulSet);
- `vault-agent-injector-*` - webhook injector.

Образы: `hashicorp/vault:1.18.1`, `hashicorp/vault-k8s:1.5.0`.

## Ingress и hosts

Правило Ingress слушает **Host** `vault.local`. Запрос на голый IP контроллера это правило не возьмёт.

IP:

```
multipass exec k8s-master -- kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Файл `hosts` у Windows и WSL **может быть раздельным** (если нет общего bridge / `generateHosts`). Тогда:

- `curl` из WSL: строка в Linux `/etc/hosts`;
- браузер Windows: строка в `C:\Windows\System32\drivers\etc\hosts`.

```
<INGRESS_IP> vault.local
```

Проверка из WSL:

```
curl -sS http://vault.local/
```

Ожидаемый ответ: redirect на `/ui/` (`Temporary Redirect`). UI и токен `root` только для лаборатории, не для продакшена.

Без записи в `hosts`:

```
curl -sS -H "Host: vault.local" http://<INGRESS_IP>/
```
