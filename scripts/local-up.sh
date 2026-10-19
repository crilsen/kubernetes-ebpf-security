#!/usr/bin/env bash
# Bring up the complete local lab on kind.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ebpf-lab}"
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
TETRAGON_VERSION="${TETRAGON_VERSION:-1.7.1}"
WEB_PORT="${WEB_PORT:-8080}"
RUN_DIR="$ROOT_DIR/.run"

STEP="preflight"
trap 'print_failure_context "$STEP"' ERR

step() {
  STEP="$1"
  log "==> $1"
}

step "check required tools"
require_cmd docker kind kubectl helm jq
docker info >/dev/null 2>&1 || die "Docker is not running; start Docker Desktop (or another daemon) and retry."

# A slow first image pull can leave a Helm release in pending-*. Clear it so the
# next run can install cleanly.
reconcile_pending_release() {
  local name="$1" status
  status="$(helm -n kube-system status "$name" -o json 2>/dev/null | jq -r '.info.status // empty')"
  if [[ "$status" == pending-* ]]; then
    warn "Helm release $name is in $status state; removing it before reinstalling"
    helm uninstall "$name" -n kube-system --wait || true
  fi
}

mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
if [[ "$mem_bytes" =~ ^[0-9]+$ ]] && (( mem_bytes > 0 && mem_bytes < 7000000000 )); then
  warn "Docker has less than ~7 GB of memory; the lab may be slow or fail to schedule pods."
fi

mkdir -p "$RUN_DIR"

step "create kind cluster ($CLUSTER_NAME)"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  log "cluster $CLUSTER_NAME already exists; reusing it"
else
  kind create cluster --config "$ROOT_DIR/deployments/local-kind/cluster/kind.yaml" --wait 120s
fi
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

step "add helm repositories"
helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
helm repo add tetragon https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update cilium tetragon >/dev/null

step "install Cilium $CILIUM_VERSION (CNI, kube-proxy replacement, Hubble)"
reconcile_pending_release cilium
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/cilium-values.yaml" \
  --wait --timeout 15m

if command -v cilium >/dev/null 2>&1; then
  cilium status --wait --namespace kube-system
else
  warn "cilium CLI not found; skipping 'cilium status'. Install it for richer diagnostics."
fi

step "install Tetragon $TETRAGON_VERSION"
reconcile_pending_release tetragon
helm upgrade --install tetragon cilium/tetragon \
  --namespace kube-system \
  --version "$TETRAGON_VERSION" \
  --values "$ROOT_DIR/deployments/local-kind/helm/tetragon-values.yaml" \
  --wait --timeout 15m

step "build application images"
docker build -t ebpf-lab/api:dev "$ROOT_DIR/app/api"
docker build -t ebpf-lab/web:dev "$ROOT_DIR/app/web"

step "load images into the kind cluster"
kind load docker-image --name "$CLUSTER_NAME" ebpf-lab/api:dev ebpf-lab/web:dev

step "deploy the application"
kubectl apply -k "$ROOT_DIR/deployments/local-kind/overlay"

step "apply baseline Cilium policies"
kubectl apply -f "$ROOT_DIR/policies/cilium/baseline"

step "apply Tetragon observation policy"
kubectl apply -f "$ROOT_DIR/policies/tetragon/observe-exec.yaml"

step "wait for workloads"
kubectl -n ebpf-lab rollout status deployment/postgres --timeout=180s
kubectl -n ebpf-lab rollout status deployment/api --timeout=180s
kubectl -n ebpf-lab rollout status deployment/web --timeout=180s

step "run smoke tests"
WEB_URL="http://127.0.0.1:${WEB_PORT}" "$ROOT_DIR/scripts/smoke-test.sh"

step "expose the Hubble UI locally"
if [[ -f "$RUN_DIR/hubble-ui.pid" ]] && kill -0 "$(cat "$RUN_DIR/hubble-ui.pid")" 2>/dev/null; then
  log "Hubble UI port-forward already running"
else
  nohup kubectl -n kube-system port-forward svc/hubble-ui 8081:80 \
    >"$RUN_DIR/hubble-ui.log" 2>&1 &
  echo $! >"$RUN_DIR/hubble-ui.pid"
fi

log ""
log "Local lab is ready."
log "  Web application : http://127.0.0.1:${WEB_PORT}"
log "  Hubble UI       : http://127.0.0.1:8081"
log "  Namespace       : ebpf-lab"
log "  Teardown        : make down"
log "  Scenarios       : make demo-list"
