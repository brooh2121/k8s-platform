# OpenTofu: установка HashiCorp Vault

Скрипт: `scripts-tofu/install-vault.sh`

Манифесты:
- `manifests/vault/helm-values.yaml` - standalone + PVC `local-path`;
- `manifests/vault/unsealer.yaml` - учебный цикл unseal после рестарта;
- `manifests/vault-ingress.yaml`.

Ресурс: `null_resource.install_vault` в `opentofu/main.tf`

Зависит от `null_resource.install_ingress`.

Интеграция с Kubernetes (auth, policy, учебный Pod): `docs/terraform/09-vault-injector.md`.

## Назначение

Поставить Vault в namespace `vault` в режиме **standalone** (file storage на PVC), не `-dev`.

Данные на диске ноды через StorageClass `local-path`. После рестарта пода Vault снова **sealed** - Shamir, не потеря KV. Скрипт делает `operator init` (1 ключ), пишет Secret `vault-init` и ставит Deployment `vault-unsealer`, который повторяет `operator unseal`. Это автоматизация Shamir, не auto-unseal через KMS.

Chart включает **Vault Agent Injector**. Ingress `vault.local` - опция, для лаборатории достаточно CLI.

## Почему helm upgrade с -dev не проходит

У StatefulSet поле `volumeClaimTemplates` нельзя добавить к уже созданному STS. Chart с `-dev` живёт на EmptyDir, standalone просит PVC. Helm пишет `failed`, а в кластере остаётся старый под `vault server -dev`.

Скрипт это видит (в args есть `-dev`), делает `helm uninstall` и удаляет STS/PVC, затем ставит заново. Весь кластер Multipass для этого сносить не нужно.

Вторая причина: на kubeadm **нет StorageClass**. Даже чистый standalone завис бы на Pending PVC. Скрипт ставит rancher `local-path-provisioner` v0.0.30.

Нельзя подменять `server.standalone.config` одной строкой `storage "file" ...`: Helm затирает весь конфиг chart, пропадает listener.

## Порядок install-vault.sh

1. Helm v3.16.4 при необходимости;
2. StorageClass `local-path`, если её нет;
3. namespace `vault`;
4. снос -dev STS, если он ещё живой;
5. chart `vault-helm` v0.29.1 с GitHub;
6. `helm upgrade --install -f /tmp/vault-values.yaml`;
7. ждать API (`vault status -format=json`), не Ready;
8. `vault operator init` + Secret `vault-init` + unseal;
9. Deployment `vault-unsealer`;
10. Ingress.

## 503 после delete pod vault-0

Тест persistence: `kv put` -> удалить под -> `kv get`. PVC живой, секрет на диске. Пока новый процесс sealed, API отвечает **503**. Это не "хранилище стёрлось".

Настоящий auto-unseal HashiCorp - ключ в AWS KMS / GCP KMS / Azure Key Vault / Transit. На Multipass этого нет, и тащить облако ради стенда незачем.

Ключ уже лежит в `vault-init` (etcd). Повторять `operator unseal` из него - честный учебный костыль: замок и ключ в одном кластере. В проде так не делают.

Unsealer идёт под SA `vault-unseal`, не под `default`. Role разрешает только `get` Secret `vault-init`. Текущий под ключ берёт через `secretKeyRef` (kubelet), в API за секретом не ходит; Role пригодится, если чтение перенесут на kubectl.

Проверка после apply:

```
multipass exec k8s-master -- kubectl delete pod vault-0 -n vault
# подождать Ready 1/1 (unsealer, обычно < 15s)
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- env VAULT_TOKEN=<root> vault kv get secret/prod-test
```

## Отладка: Running, но Ready 0/1

Это ожидаемо, пока Vault **sealed** или **не инициализирован**. Readiness probe chart - команда `vault status`. Она завершается с кодом 2 и печатает таблицу `Key / Value`. kubelet пишет `Readiness probe failed` - это не падение контейнера.

Сразу смотрите сам статус, код 2 можно игнорировать:

```
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault status
```

Как читать:

- `Initialized false`, `Sealed true` - ещё не делали `vault operator init` (в логах пода: `seal configuration missing`). Нужен init, не delete cluster.
- `Initialized true`, `Sealed true` - данные на PVC есть, без unseal-ключа Ready не станет. Ключ в Secret `vault-init`. Если секрета нет - ключ потерян, для лаборатории снести PVC `data-vault-0` и под, затем снова init.
- `Sealed false` - API живой, Ready должен стать 1/1 через несколько проб.

Дополнительно:

```
multipass exec k8s-master -- kubectl get pvc -n vault
multipass exec k8s-master -- kubectl get secret vault-init -n vault
multipass exec k8s-master -- kubectl logs vault-0 -n vault --tail=50
```

`vault status -format=json` тоже даёт exit 2, пока sealed. Скрипт это учитывает: парсит JSON, не считает exit кодом фатальной ошибкой.

## Проверка

```
multipass exec k8s-master -- kubectl get pods -n vault
multipass exec k8s-master -- kubectl get pvc -n vault
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault status
```

Ожидание: `Storage Type` = `file`, `Sealed` = `false`, PVC Bound.

Root token (учебный секрет в etcd):

```
multipass exec k8s-master -- kubectl get secret vault-init -n vault -o jsonpath='{.data.root}' | wsl -e bash -lc 'base64 -d'; echo
```

Или с master:

```
multipass exec k8s-master -- kubectl get secret vault-init -n vault -o jsonpath='{.data.root}'
```

CLI внутри пода:

```
ROOT=$(multipass exec k8s-master -- kubectl get secret vault-init -n vault -o jsonpath='{.data.root}' )
# дальше на master:
kubectl exec -n vault vault-0 -- env VAULT_TOKEN=<root> vault status
```

## Ingress и hosts

Правило слушает Host `vault.local`. WSL и Windows могут иметь **разные** `/etc/hosts`.

```
<INGRESS_IP> vault.local
```

`curl http://vault.local/` - redirect на `/ui/`. Токен - из `vault-init`, не `root`.
