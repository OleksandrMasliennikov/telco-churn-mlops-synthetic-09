#!/usr/bin/env bash
# =============================================================================
# monitoring/k8s/deploy-monitoring-k3s.sh
# One-shot script: install kube-prometheus-stack + wire up dashboards/alerts
# for the telco-churn-mlops app running on k3s.
# =============================================================================
set -euo pipefail

MONITORING_NS="monitoring"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

info "Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

info "Creating namespace ${MONITORING_NS}..."
kubectl create namespace "${MONITORING_NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${MONITORING_NS}" app.kubernetes.io/managed-by=Helm --overwrite

info "Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace "${MONITORING_NS}" \
  -f "${REPO_ROOT}/monitoring/k8s/values.yaml" \
  --wait --timeout 10m

info "Applying churn-api Service, ServiceMonitor and PrometheusRule..."
kubectl apply -f "${REPO_ROOT}/deployment/service-churn-api.yaml"
kubectl apply -f "${REPO_ROOT}/deployment/servicemonitor-churn-api.yaml"
kubectl apply -f "${REPO_ROOT}/deployment/prometheusrule-ml.yaml"

info "Applying Grafana dashboard ConfigMaps (grafana_dashboard=1 sidecar labels)..."
kubectl apply -k "${REPO_ROOT}/monitoring/k8s"

info "Done. Port-forward Grafana with:"
echo "  kubectl port-forward svc/kube-prom-stack-grafana 3000:80 -n ${MONITORING_NS}"
echo "  admin / mlops-secure-pass"
