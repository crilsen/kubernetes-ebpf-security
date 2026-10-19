#!/usr/bin/env bash
# Scenario 3: runtime observation with Tetragon. Executes a process in a lab pod
# and prints the events Tetragon captured. Nothing is blocked.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

require_cmd kubectl

log "==> confirming the observation policy is loaded"
kubectl get tracingpolicy observe-process-exec >/dev/null

log "==> capturing Tetragon events for 10s and executing a process meanwhile"
tmp="$(mktemp)"
set +e
run_with_timeout 10 kubectl -n kube-system exec daemonset/tetragon -c tetragon -- \
  tetra getevents -o compact --namespace ebpf-lab >"$tmp" 2>&1 &
watcher=$!
set -e

sleep 2
kubectl -n ebpf-lab exec deployment/api -- ls / >/dev/null
wait "$watcher" || true

log "==> Tetragon events"
cat "$tmp"

if ! grep -qi "process" "$tmp" 2>/dev/null; then
  warn "no events were captured in the window; re-run or increase the observation time"
fi
rm -f "$tmp"

log "==> runtime observation scenario complete"
