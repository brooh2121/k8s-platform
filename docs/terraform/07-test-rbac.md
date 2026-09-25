# OpenTofu: проверка RBAC

Скрипт: `scripts-tofu/test-rbac.sh`

Ресурс: `null_resource.test_rbac` в `opentofu/main.tf`

Зависит от `null_resource.install_rbac`.

## Назначение

После применения манифестов проверить роли через `kubectl auth can-i` (impersonation ServiceAccount). Kubeconfig и SA-токены для этого не нужны.

Если проверка не совпала с ожиданием, `tofu apply` падает.

## Ожидания

developer (`system:serviceaccount:dev:developer`):
- может создавать Deployment и читать Pod в `dev`;
- не может читать Pod в `user-space` и Nodes.

user (`system:serviceaccount:user-space:user`):
- может читать Pod и ConfigMap в `user-space`;
- не может создавать Deployment, читать чужой namespace и удалять Nodes.

devops (`system:serviceaccount:default:devops`):
- ClusterRole `*/*` - Nodes и Pod в чужих namespace разрешены.

## Проверка вручную

```
multipass exec k8s-master -- /tmp/test-rbac.sh
```
