#!/usr/bin/env bash
# Validate the runtime dashboard: Grafana health, provisioned dashboard, and
# Tetragon events arriving through Loki.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3001}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:lab-demo-password}"

require_cmd curl jq

log "==> Grafana health"
curl -fsS --max-time 5 "$GRAFANA_URL/api/health" | jq -e '.database == "ok"' >/dev/null \
  || die "Grafana is not healthy at $GRAFANA_URL (run make up first)"

log "==> provisioned dashboard"
dashboards="$(curl -fsS --max-time 5 -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/search?query=Tetragon")"
echo "$dashboards" | jq -r '.[].title' | grep -q "Tetragon runtime events" \
  || die "the Tetragon dashboard is not provisioned"

log "==> Tetragon events in Loki"
events="$(curl -fsS --max-time 10 -u "$GRAFANA_AUTH" -G \
  "$GRAFANA_URL/api/datasources/proxy/uid/loki/loki/api/v1/query_range" \
  --data-urlencode 'query={job="tetragon"} |= "process_exec"' \
  --data-urlencode 'limit=5' \
  --data-urlencode 'since=10m' | jq -r '[.data.result[].values[]] | length')"

echo "events found: $events"
[[ "$events" -gt 0 ]] || die "no Tetragon events reached Loki; check the promtail logs"

log "==> runtime dashboard OK: $GRAFANA_URL (admin / lab-demo-password)"
