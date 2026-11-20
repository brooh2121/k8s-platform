# OpenTofu: kube-prometheus-stack

Скрипт: `scripts-tofu/install-monitoring.sh`

Ресурс: `null_resource.install_monitoring` в `opentofu/main.tf`

## Назначение

Поставить Prometheus, Grafana и Alertmanager в namespace `monitoring`.

## Почему Grafana была Pending

Helm при `grafana.persistence.enabled=true` **сам** создаёт PVC. Ручной PVC не нужен.

На kubeadm нет default StorageClass. PVC без `storageClassName` остаётся Unbound, планировщик пишет `pod has unbound immediate PersistentVolumeClaims`, `helm --wait` падает по таймауту.

То же, что было у Vault: нужен rancher `local-path`. Скрипт ставит его, если класса ещё нет, и задаёт `grafana.persistence.storageClassName=local-path`.

Если PVC Grafana уже создан без класса, helm поле не поменяет. Скрипт удаляет только Pending PVC Grafana без StorageClass, релиз создаёт новый.

Prometheus по умолчанию без PVC (emptyDir), диск не занимает.

## Проверка

```
multipass exec k8s-master -- kubectl get pods -n monitoring
multipass exec k8s-master -- kubectl get pvc -n monitoring
multipass exec k8s-master -- kubectl get storageclass
```

PVC Grafana должен быть Bound, под Grafana Running.
