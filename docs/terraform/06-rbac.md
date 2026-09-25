# OpenTofu: установка RBAC

Скрипт: `scripts-tofu/install-rbac.sh`

Манифесты: `manifests/rbac/`

Ресурс: `null_resource.install_rbac` в `opentofu/main.tf`

## Назначение

Создать учебные ServiceAccount, Role/ClusterRole и RoleBinding:

- `developer` в namespace `dev` - правки Deploy/Pod/PVC в своем namespace;
- `user` в namespace `user-space` - только чтение Pod/Service/ConfigMap;
- `devops` в `default` - ClusterRole на все ресурсы.

## Почему падал `file` provisioner

`provisioner "file"` через scp копирует **файл**. Если `source` - каталог, а `destination = "/tmp/rbac/"`, scp отвечает:

```
Upload failed: scp: /tmp/rbac/: Is a directory
```

Каталог целиком так не заливают. Нужно либо заранее создать папку и копировать файлы по одному, либо отдать YAML через `content = file(...)`.

Как сделано сейчас:
1. `mkdir -p /tmp/rbac`;
2. каждый YAML читается tofu на хосте (`abspath` к Windows-checkout в WSL) и пишется в `/tmp/rbac/<name>.yaml`;
3. скрипт делает `kubectl apply -f /tmp/rbac/`.

## Проверка

```
multipass exec k8s-master -- ls /tmp/rbac
multipass exec k8s-master -- kubectl get sa,role,rolebinding -n dev
multipass exec k8s-master -- kubectl get sa devops
multipass exec k8s-master -- kubectl get clusterrole devops-role
```
