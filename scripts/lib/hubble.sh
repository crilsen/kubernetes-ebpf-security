#!/usr/bin/env bash
# Start a local port-forward to hubble-relay on 127.0.0.1:4245 if needed.
# Source this file, then use `hubble observe --server "$HUBBLE_SERVER"`.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

RUN_DIR="$ROOT_DIR/.run"
mkdir -p "$RUN_DIR"

command -v hubble >/dev/null 2>&1 || die "hubble CLI not found (install the Cilium CLI to use flow demos)"
kubectl -n kube-system get svc hubble-relay >/dev/null 2>&1 || die "hubble-relay service not found; is Cilium installed?"

HUBBLE_SERVER="127.0.0.1:4245"

if [[ -f "$RUN_DIR/hubble-relay.pid" ]] && kill -0 "$(cat "$RUN_DIR/hubble-relay.pid")" 2>/dev/null; then
  log "hubble relay already forwarded at $HUBBLE_SERVER"
else
  nohup kubectl -n kube-system port-forward svc/hubble-relay 4245:80 \
    >"$RUN_DIR/hubble-relay.log" 2>&1 &
  echo $! >"$RUN_DIR/hubble-relay.pid"

  for _ in $(seq 1 30); do
    if (exec 3<>/dev/tcp/127.0.0.1/4245) 2>/dev/null; then
      exec 3>&-
      break
    fi
    sleep 1
  done

  if ! (exec 3<>/dev/tcp/127.0.0.1/4245) 2>/dev/null; then
    die "hubble-relay port-forward did not become ready; see $RUN_DIR/hubble-relay.log"
  fi
  exec 3>&-
  log "hubble relay available at $HUBBLE_SERVER"
fi

export HUBBLE_SERVER
