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
"$ROOT_DIR/scripts/install-deps.sh" --check
require_cmd docker kind kubectl helm jq
docker info >/dev/null 2>&1 || die "Docker is not running; start Docker Desktop (or another daemon) and retry."

# A slow first image pull can leave a Helm release in pending-*. Clear it so the
# next run can install cleanly.
reconcile_pending_release() {
  local name="$1" status
  status="$(helm -n kube-system status "$name" -o json 2>/dev/null | jq -r '.info.status // empty' || true)"
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
# Images use a fixed :dev tag, so restart to pick up a freshly loaded build even
# when the manifest did not change.
kubectl -n ebpf-lab rollout restart deployment/api deployment/web >/dev/null

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

step "expose local endpoints"
start_forward() {
  local name="$1" namespace="$2" service="$3" local_port="$4" remote_port="$5"
  local pidfile="$RUN_DIR/$name.pid"
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    log "$name port-forward already running on 127.0.0.1:$local_port"
  else
    nohup kubectl -n "$namespace" port-forward "svc/$service" "${local_port}:${remote_port}" \
      >"$RUN_DIR/$name.log" 2>&1 &
    echo $! >"$pidfile"
  fi
  for _ in $(seq 1 20); do
    if (exec 3<>/dev/tcp/127.0.0.1/"$local_port") 2>/dev/null; then
      exec 3>&-
      return 0
    fi
    sleep 1
  done
  warn "$name port-forward did not become ready on 127.0.0.1:$local_port; see $RUN_DIR/$name.log"
}

start_forward api ebpf-lab api "${API_PORT:-8082}" 8080
start_forward hubble-ui kube-system hubble-ui "${HUBBLE_UI_PORT:-8081}" 80
start_forward hubble-relay kube-system hubble-relay "${HUBBLE_RELAY_PORT:-4245}" 80

log ""
log "Local lab is ready."
log ""
log "  Web application   http://127.0.0.1:${WEB_PORT}"
log "  API direct        http://127.0.0.1:${API_PORT:-8082}/api/message"
log "  API health        http://127.0.0.1:${API_PORT:-8082}/healthz"
log "  Hubble UI         http://127.0.0.1:${HUBBLE_UI_PORT:-8081}"
log "  Hubble Relay      grpc://127.0.0.1:${HUBBLE_RELAY_PORT:-4245} (hubble observe --server)"
log "  Kubernetes        context kind-$CLUSTER_NAME, namespace ebpf-lab"
log ""
log "  Teardown          make down"
log "  Scenarios         make demo-list"
log "  Validate          make smoke"
