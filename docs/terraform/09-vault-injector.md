# OpenTofu: Vault Agent Injector и Kubernetes auth

Скрипт: `scripts-tofu/configure-vault.sh`

Манифесты:
- `manifests/vault/policy.hcl` - политика чтения KV;
- `manifests/vault/test-pod.yaml` - ServiceAccount и учебный Pod.

Ресурсы в `opentofu/main.tf`:
- `null_resource.configure_vault` (после `install_vault`);
- `null_resource.test_vault_integration` (после `configure_vault`).

Установка сервера и injector: `docs/terraform/08-vault.md`.

## Зачем так

Самый простой учебный путь: секрет живёт в Vault, под доказывает личность через **ServiceAccount**, injector монтирует файл. Отдельный Kubernetes `Secret` с паролем для приложения не нужен.

Направление такое: Vault - источник, кластер только говорит «это SA `test-sa` в `default`».

## Что делает configure-vault.sh

Команды идут в под `vault-0` (`kubectl exec`). В dev CLI внутри пода уже ходит на `http://127.0.0.1:8200` с токеном `root`.

1. `vault auth enable kubernetes` (повторный запуск не падает);
2. `auth/kubernetes/config` с `kubernetes_host=https://kubernetes.default.svc:443`;
3. политика `test-policy` из `policy.hcl`;
4. роль `test-role`: SA `test-sa`, namespace `default`, политика `test-policy`, TTL 1h;
5. учебный секрет `vault kv put secret/test` (kv-v2 в dev уже на пути `secret/`).

Политика читает путь KV v2:

```
path "secret/data/test" {
  capabilities = ["read"]
}
```

Для API это `secret/data/test`, для `vault kv put` / аннотации injector - логический путь `secret/data/test` (как в `test-pod.yaml`).

## Учебный Pod

`manifests/vault/test-pod.yaml`:
- ServiceAccount `test-sa` в `default`;
- Pod `test-vault-pod`, `serviceAccountName: test-sa`;
- аннотации injector:
  - `vault.hashicorp.com/agent-inject: "true"`;
  - `vault.hashicorp.com/role: "test-role"`;
  - `vault.hashicorp.com/agent-inject-secret-test.txt: "secret/data/test"`.

Webhook добавляет init/sidecar. Файл появляется как `/vault/secrets/test.txt`. Контейнер `app` (alpine) печатает файл и спит.

Injector в кластере берёт Vault по адресу сервиса `http://vault.vault.svc:8200` (значение chart по умолчанию).

## Порядок tofu

1. `install_vault` - Helm, `vault-0`, injector, Ingress;
2. `configure_vault` - kubernetes auth, policy, role, KV;
3. `test_vault_integration` - `kubectl apply` манифеста, пауза 15s, `kubectl logs` приложения.

`apply` существующего Pod не пересоздаёт контейнер. Повторная проверка с нуля:

```
multipass exec k8s-master -- kubectl delete pod test-vault-pod -n default --ignore-not-found
multipass exec k8s-master -- kubectl apply -f /tmp/test-pod.yaml
```

Либо сменить `pod_sha` / удалить ресурс и прогнать apply снова.

## Проверка

Поды Vault:

```
multipass exec k8s-master -- kubectl get pods -n vault
```

Учебный под (должен быть Running, часто 2/2 из-за sidecar):

```
multipass exec k8s-master -- kubectl get pod test-vault-pod -n default
multipass exec k8s-master -- kubectl logs test-vault-pod -n default -c app
```

В логах `app` ожидаются ключи `username` / `password` (или JSON от агента). Файл:

```
multipass exec k8s-master -- kubectl exec -n default test-vault-pod -c app -- cat /vault/secrets/test.txt
```

Auth и политика:

```
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault auth list
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault policy list
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- vault kv get secret/test
```

Если под в `Init:0/1` или нет файла: события `kubectl describe pod test-vault-pod -n default`, логи контейнера `vault-agent`. Частые причины: роль не совпала с SA/namespace, секрета нет, injector не Running.

## Ограничения стенда

Dev-режим: после рестарта `vault-0` секреты, auth и role пропадают, `configure_vault` нужно прогнать снова (или весь apply по trigger). Это не production (нет Raft, PVC, TLS, Shamir unseal).
