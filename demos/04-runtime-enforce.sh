#!/usr/bin/env bash
# Scenario 4: controlled enforcement. A dedicated workload gets a Tetragon policy
# that kills shell execution. The baseline namespace is not touched.
#
# This is a narrow demonstration, not a general anti-shell control.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

require_cmd kubectl

cleanup() {
  kubectl delete -f "$ROOT_DIR/policies/tetragon/enforce-deny-shell.yaml" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete -f "$ROOT_DIR/demos/runtime-target/target.yaml" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "==> creating the dedicated enforcement namespace and workload"
kubectl apply -f "$ROOT_DIR/demos/runtime-target/target.yaml"
kubectl -n ebpf-lab-enforce rollout status deployment/runtime-target --timeout=180s

log "==> applying the enforcement policy (SIGKILL on shell exec)"
kubectl apply -f "$ROOT_DIR/policies/tetragon/enforce-deny-shell.yaml"
sleep 3

log "==> capturing Tetragon events while attempting /bin/sh (expected to be killed)"
tmp="$(mktemp)"
set +e
run_with_timeout 8 kubectl -n kube-system exec daemonset/tetragon -c tetragon -- \
  tetra getevents -o compact --namespace ebpf-lab-enforce >"$tmp" 2>&1 &
watcher=$!
set -e
sleep 2

set +e
output="$(kubectl -n ebpf-lab-enforce exec deployment/runtime-target -- /bin/sh -c 'echo SHOULD_NOT_PRINT' 2>&1)"
status=$?
set -e
echo "$output"
sleep 2
wait "$watcher" 2>/dev/null || true

log "==> Tetragon events"
cat "$tmp"
rm -f "$tmp"

if [[ $status -eq 0 && "$output" == *SHOULD_NOT_PRINT* ]]; then
  die "the shell ran despite the enforcement policy"
fi
log "shell execution was blocked (exit code $status)"

log "==> cleanup (policy and target workload removed)"
cleanup
trap - EXIT

log "==> enforcement scenario complete"
