#!/usr/bin/env bash
# Stop local port-forwards and delete only this POC's kind cluster.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ebpf-lab}"
RUN_DIR="$ROOT_DIR/.run"

require_cmd kind

if [[ -d "$RUN_DIR" ]]; then
  for pidfile in "$RUN_DIR"/*.pid; do
    [[ -e "$pidfile" ]] || continue
    pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      log "stopping port-forward pid $pid ($(basename "$pidfile"))"
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
  done
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  log "deleting kind cluster $CLUSTER_NAME"
  kind delete cluster --name "$CLUSTER_NAME"
else
  log "kind cluster $CLUSTER_NAME does not exist; nothing to delete"
fi

log "local lab stopped"
