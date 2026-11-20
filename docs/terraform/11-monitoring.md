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

## Почему Grafana 2/3 и Unhealthy на /api/health

PVC уже Bound. Контейнер Grafana 13 стартует, минутами грузит плагины и до `HTTP listen :3000` не доходит. Kubelet бьёт liveness, видит `connection refused`, убивает процесс. Sidecar'ы (dashboard/datasource) уже Running, поэтому 2/3.

Скрипт ставит `startupProbe` на `/api/health` (до ~10 мин) и небольшие requests по CPU/RAM. Destroy не нужен: `tofu apply` обновит Deployment.

Если apply оборвался на `helm --wait`, релиз остаётся `pending-upgrade`. Повторный apply пишет `another operation (install/upgrade/rollback) is in progress`. Живого процесса helm обычно нет: это Secret `sh.helm.release.v1.*`. Скрипт удаляет pending Secret перед `upgrade --install`.

## Проверка

```
multipass exec k8s-master -- kubectl get pods -n monitoring
multipass exec k8s-master -- kubectl get pvc -n monitoring
multipass exec k8s-master -- kubectl get storageclass
```

PVC Grafana должен быть Bound, под Grafana 3/3 Running. Первая загрузка плагинов на worker может занять несколько минут.
