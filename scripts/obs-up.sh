#!/usr/bin/env bash
# Install Loki, Promtail, and Grafana for the Tetragon runtime dashboard.
# Idempotent; called by local-up.sh after Tetragon is ready.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

LOKI_VERSION="${LOKI_VERSION:-7.3.0}"
PROMTAIL_VERSION="${PROMTAIL_VERSION:-6.17.1}"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-29.37.0}"
GRAFANA_VERSION="${GRAFANA_VERSION:-10.5.15}"
NAMESPACE="observability"

require_cmd helm kubectl

log "==> add Grafana and Prometheus helm repositories"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update grafana prometheus-community >/dev/null

log "==> install Loki $LOKI_VERSION"
helm upgrade --install loki grafana/loki \
  --namespace "$NAMESPACE" --create-namespace \
  --version "$LOKI_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/loki-values.yaml" \
  --wait --timeout 15m

log "==> install Promtail $PROMTAIL_VERSION"
helm upgrade --install promtail grafana/promtail \
  --namespace "$NAMESPACE" \
  --version "$PROMTAIL_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/promtail-values.yaml" \
  --wait --timeout 10m

log "==> install Prometheus $PROMETHEUS_VERSION"
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace "$NAMESPACE" \
  --version "$PROMETHEUS_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/prometheus-values.yaml" \
  --wait --timeout 10m

log "==> install Grafana $GRAFANA_VERSION"
helm upgrade --install grafana grafana/grafana \
  --namespace "$NAMESPACE" \
  --version "$GRAFANA_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/grafana-values.yaml" \
  --wait --timeout 10m

log "==> observability stack ready"
