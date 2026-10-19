#!/usr/bin/env bash
# Scenario 2: microsegmentation. A probe pod in the same namespace cannot reach
# the API, while web can. Proves default-deny plus explicit allowances.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/hubble.sh
source "$ROOT_DIR/scripts/lib/hubble.sh"

require_cmd kubectl

cleanup() {
  kubectl -n ebpf-lab delete pod probe --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "==> allowed path: web -> api"
kubectl -n ebpf-lab exec deployment/web -- \
  wget -qO- --timeout=5 http://api:8080/healthz
echo

log "==> starting an unlabeled probe pod inside the same namespace"
kubectl -n ebpf-lab delete pod probe --ignore-not-found >/dev/null 2>&1 || true
kubectl -n ebpf-lab run probe --image=curlimages/curl:8.10.1 --labels app=probe \
  --command -- sleep 3600 >/dev/null
kubectl -n ebpf-lab wait --for=condition=Ready pod/probe --timeout=120s >/dev/null

log "==> probe -> api (expected to fail: DNS and API egress are denied)"
set +e
output="$(kubectl -n ebpf-lab exec probe -- curl -sS --max-time 5 http://api:8080/healthz 2>&1)"
status=$?
set -e
echo "$output"
if [[ $status -eq 0 ]]; then
  die "probe reached the API; default-deny is not in effect"
fi
log "probe was denied as expected (exit code $status)"

log "==> dropped flows recorded by Hubble"
hubble observe --server "$HUBBLE_SERVER" --namespace ebpf-lab --verdict DROPPED --last 20 -o compact || true

log "==> cleanup"
cleanup
trap - EXIT

log "==> microsegmentation scenario complete"
