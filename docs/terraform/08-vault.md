# OpenTofu: установка HashiCorp Vault

Скрипт: `scripts-tofu/install-vault.sh`

Манифесты:
- `manifests/vault/helm-values.yaml` - standalone + PVC `local-path`;
- `manifests/vault-ingress.yaml`.

Ресурс: `null_resource.install_vault` в `opentofu/main.tf`

Зависит от `null_resource.install_ingress`.

Интеграция с Kubernetes (auth, policy, учебный Pod): `docs/terraform/09-vault-injector.md`.

## Назначение

Поставить Vault в namespace `vault` в режиме **standalone** (file storage на PVC), не `-dev`.

Данные на диске ноды через StorageClass `local-path`. После рестарта пода Vault **sealed**: скрипт делает `operator init` (1 ключ) и `unseal`. Корневой токен больше не строка `root`.

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
7. ждать **Running** (не Ready: sealed под не Ready);
8. `vault operator init` + Secret `vault-init` + unseal;
9. Ingress.

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
