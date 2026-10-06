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

Секрет живёт в Vault, под доказывает личность через **ServiceAccount**, injector кладёт файл в `/vault/secrets`. Обычный Kubernetes `Secret` с паролем не нужен.

## Что делает configure-vault.sh

Root token читается из Secret `vault/vault-init` (его пишет `install-vault.sh` после init). Команды: `kubectl exec` с `VAULT_TOKEN`.

1. `vault secrets enable -path=secret kv-v2` (в standalone сам не появляется);
2. `vault auth enable kubernetes`;
3. `auth/kubernetes/config` с `kubernetes_host=https://kubernetes.default.svc:443`;
4. политика `test-policy`;
5. роль `test-role`: SA `test-sa`, namespace `default`, TTL 1h;
6. `vault kv put secret/test username=demo password=lab`.

Политика KV v2:

```
path "secret/data/test" {
  capabilities = ["read"]
}
```

После пересоздания Vault `configure_vault` должен прогнаться снова: в tofu trigger завязан на `null_resource.install_vault.id`.

## Учебный Pod

Аннотации:
- `vault.hashicorp.com/agent-inject: "true"`;
- `vault.hashicorp.com/role: "test-role"`;
- `vault.hashicorp.com/agent-inject-secret-test.txt: "secret/data/test"`.

`test_vault_integration` удаляет старый `test-vault-pod` и применяет манифест заново.

## Проверка

```
multipass exec k8s-master -- kubectl get pods -n vault
multipass exec k8s-master -- kubectl get pod test-vault-pod -n default
multipass exec k8s-master -- kubectl logs test-vault-pod -n default -c app
multipass exec k8s-master -- kubectl exec -n default test-vault-pod -c app -- cat /vault/secrets/test.txt
```

CLI с токеном (подставьте root из `vault-init`):

```
multipass exec k8s-master -- kubectl exec -n vault vault-0 -- env VAULT_TOKEN=<root> vault kv get secret/test
```

## Ограничения стенда

Standalone + file + 1 unseal key - учебный шаг, не production. Нет Raft HA, TLS, auto-unseal. Secret `vault-init` в кластере хранит ключ и root token - только для лаборатории.

После удаления PVC Vault нужно инициализировать заново (скрипт это делает, если `initialized=false`). Если PVC живой, а Secret `vault-init` потерян - скрипт остановится: unseal-ключ больше негде взять.
