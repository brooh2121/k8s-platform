#!/bin/bash
# ============================================
# Установка kube-prometheus-stack
# Prometheus + Grafana + Alertmanager
# ============================================

set -e

echo "[MONITORING] Installing kube-prometheus-stack..."

# 1. Создаём неймспейс
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# 2. Добавляем репозиторий
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 3. Устанавливаем стек
# Используем values, чтобы:
# - включить Grafana
# - дать Grafana LoadBalancer/Ingress позже
# - ограничить ресурсы (у нас маленькие VM)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set grafana.adminPassword=admin123 \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=128Mi \
  --set prometheusOperator.resources.requests.memory=128Mi \
  --set kube-state-metrics.resources.requests.memory=64Mi \
  --set nodeExporter.resources.requests.memory=32Mi \
  --timeout 10m \
  --wait

echo "[MONITORING] Waiting for pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=180s || true

echo "[MONITORING] Stack installed."
kubectl get pods -n monitoring