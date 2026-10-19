#!/usr/bin/env bash
# Scenario 1: baseline. Show the allowed path and the flows Hubble recorded.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/hubble.sh
source "$ROOT_DIR/scripts/lib/hubble.sh"

WEB_URL="${WEB_URL:-http://127.0.0.1:8080}"
require_cmd curl jq kubectl

log "==> baseline request: client -> web -> api -> postgres"
curl -fsS --max-time 10 "$WEB_URL/api/message" | jq .

log "==> allowed flows recorded by Hubble (namespace ebpf-lab)"
# Hubble reports L3/L4 flows by default; HTTP parsing needs an L7 policy.
hubble observe --server "$HUBBLE_SERVER" --namespace ebpf-lab --last 15 -o compact || true

log "==> baseline scenario complete"
