#!/usr/bin/env bash
# Scenario 5: a live denial. The web pod calls the denied-target Service, for
# which no Cilium allow rule exists. The connection is dropped and nginx
# returns 504; Hubble shows the dropped flow.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

WEB_URL="${WEB_URL:-http://127.0.0.1:8080}"
require_cmd curl kubectl

log "==> checking that the local lab is reachable"
if ! curl -fsS --max-time 5 "$WEB_URL/healthz" >/dev/null 2>&1; then
  die "frontend is not reachable at $WEB_URL; run 'make up' first"
fi

log "==> confirming the denied target is running"
kubectl -n ebpf-lab rollout status deployment/denied-target --timeout=120s

log "==> calling the denied endpoint through the web pod (expected: 504)"
code="$(curl -s -o /tmp/denied-body.$$ -w '%{http_code}' --max-time 8 "$WEB_URL/denied/healthz" || true)"
rm -f "/tmp/denied-body.$$"
echo "HTTP $code"
case "$code" in
  504 | 502 | 000) log "request was blocked as expected" ;;
  *) die "denied-target was reachable (HTTP $code); the policy is not in effect" ;;
esac

if command -v hubble >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/hubble.sh
  source "$ROOT_DIR/scripts/lib/hubble.sh"
  log "==> dropped flows recorded by Hubble"
  hubble observe --server "$HUBBLE_SERVER" --namespace ebpf-lab --verdict DROPPED --last 20 -o compact || true
else
  warn "hubble CLI not found; skipping flow output (install with: make deps)"
fi

log "==> denied endpoint scenario complete"
