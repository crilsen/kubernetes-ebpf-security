#!/usr/bin/env bash
# Scenario 6: one pod with front, back and api containers.
#  - localhost traffic between containers is not filtered by Cilium
#  - an external probe can reach the front port and is denied on back/api ports
#  - Tetragon enforcement applies to every container in the pod
#  - /policy-sim is an application-level denial, clearly labelled as simulated
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

NAMESPACE="ebpf-lab-mc"
STACK_MANIFEST="$ROOT_DIR/demos/multicontainer/stack.yaml"
CILIUM_POLICY="$ROOT_DIR/policies/cilium/scenarios/multicontainer.yaml"
TETRAGON_POLICY="$ROOT_DIR/policies/tetragon/scenarios/multicontainer-enforce.yaml"

require_cmd kubectl curl

cleanup() {
  kubectl delete tracingpolicy mc-deny-shell --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "==> deploying the multi-container pod"
kubectl apply -f "$STACK_MANIFEST"
kubectl apply -f "$CILIUM_POLICY"
kubectl -n "$NAMESPACE" rollout status deployment/stack --timeout=180s

log "==> intra-pod traffic: front -> back and front -> api over localhost"
kubectl -n "$NAMESPACE" exec deployment/stack -c front -- wget -qO- http://127.0.0.1:8081/healthz
kubectl -n "$NAMESPACE" exec deployment/stack -c front -- wget -qO- http://127.0.0.1:8082/healthz
log "localhost traffic works and is not visible to Cilium policy"

log "==> simulated denial (application-level, not a network drop)"
set +e
sim_output="$(kubectl -n "$NAMESPACE" exec deployment/stack -c front -- \
  wget -S -O- http://127.0.0.1:8081/policy-sim 2>&1)"
sim_status=$?
set -e
echo "$sim_output" | grep -E "403|Forbidden" || true
[[ $sim_status -ne 0 ]] || die "policy-sim returned success; expected a simulated 403"
log "policy-sim returned a simulated 403 (no packet was dropped)"

log "==> applying Tetragon enforcement to every container in the pod"
kubectl apply -f "$TETRAGON_POLICY"
sleep 3

for container in front back api; do
  log "shell exec in container '$container' (expected: SIGKILL)"
  set +e
  output="$(kubectl -n "$NAMESPACE" exec deployment/stack -c "$container" -- \
    /bin/sh -c 'echo SHOULD_NOT_PRINT' 2>&1)"
  status=$?
  set -e
  echo "$output"
  if [[ $status -eq 0 && "$output" == *SHOULD_NOT_PRINT* ]]; then
    die "the shell ran in container $container despite enforcement"
  fi
  log "container '$container' blocked the shell (exit $status)"
done

log "==> external probe: front allowed, back/api denied by Cilium"
kubectl -n "$NAMESPACE" delete pod probe --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NAMESPACE" run probe --image=curlimages/curl:8.10.1 --labels app=probe \
  --command -- sleep 3600 >/dev/null
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/probe --timeout=180s >/dev/null

front_code="$(kubectl -n "$NAMESPACE" exec probe -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://stack:8080/healthz || true)"
echo "front :8080 -> HTTP $front_code"
[[ "$front_code" == "200" ]] || die "front should be reachable, got HTTP $front_code"

for port in 8081 8082; do
  set +e
  kubectl -n "$NAMESPACE" exec probe -- curl -sS --max-time 5 "http://stack:${port}/healthz" >/dev/null 2>&1
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    die "container port $port was reachable; Cilium did not deny it"
  fi
  log "container port $port denied from outside (exit $status)"
done

if command -v hubble >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/hubble.sh
  source "$ROOT_DIR/scripts/lib/hubble.sh"
  log "==> dropped flows recorded by Hubble"
  hubble observe --server "$HUBBLE_SERVER" --namespace "$NAMESPACE" --verdict DROPPED --last 20 -o compact || true
else
  warn "hubble CLI not found; skipping flow output (install with: make deps)"
fi

if [[ "${KEEP:-0}" == "1" ]]; then
  log "==> keeping the scenario resources"
  log "  browser: kubectl -n $NAMESPACE port-forward svc/stack 8090:8080"
  trap - EXIT
else
  log "==> cleaning up"
  cleanup
  trap - EXIT
fi

log "==> multi-container scenario complete"
