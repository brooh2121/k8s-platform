# Terraform: ранний эксперимент с Multipass

Каталог: `terraform/`

## Назначение

Это первый набросок IaC для тех же трех VM в `Multipass`. Стек только создает машины и печатает IP. Kubernetes, сеть и платформенные компоненты здесь не ставятся.

Рабочий IaC-путь сейчас - `opentofu/`. Документ `docs/steps/08-opentofu.md`.

## Состав

- `main.tf` - провайдер `todoroff/multipass` версии `~> 1.7` и три `multipass_instance`: `k8s-master`, `k8s-worker1`, `k8s-worker2`;
- `outputs.tf` - IP master и worker-нод;
- `variables.tf` - пустой.

Ресурсы VM:
- image: `lts`;
- cpus: `2`;
- memory: `2G`;
- disk: `10G`.

На master есть `remote-exec` с командой `echo 'Hello from master node'`. Блока `connection` в этом provisioner нет.

## Как запускать

Из каталога `terraform/`:

```
terraform init
terraform apply
```

Либо `tofu`, если используете OpenTofu с этим каталогом. Имена VM совпадают с `opentofu/` и с `scripts/00-create-vms.sh`. Одновременно два стека к одним и тем же именам применять нельзя.

## Результат

Три VM в `Multipass` и вывод IP в outputs. Дальше кластер нужно ставить скриптами `scripts/01` и далее либо переходить на `opentofu/`.

## Важные замечания

- параметры захардкожены;
- нет cloud-init и SSH-ключей;
- это учебный черновик, не замена `scripts/00-create-vms.sh` и не замена `opentofu/`.
