#!/usr/bin/env bash
# Validate the runtime dashboard: Grafana health, provisioned dashboard, and
# Tetragon events arriving through Loki.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3001}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:lab-demo-password}"
WEB_URL="${WEB_URL:-http://127.0.0.1:8080}"

require_cmd curl jq

log "==> Grafana health"
curl -fsS --max-time 5 "$GRAFANA_URL/api/health" | jq -e '.database == "ok"' >/dev/null \
  || die "Grafana is not healthy at $GRAFANA_URL (run make up first)"

log "==> provisioned dashboards"
dashboards="$(curl -fsS --max-time 5 -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/search?query=")"
echo "$dashboards" | jq -r '.[].title' | grep -q "Tetragon runtime events" \
  || die "the Tetragon dashboard is not provisioned"
echo "$dashboards" | jq -r '.[].title' | grep -q "Hubble and Tetragon metrics" \
  || die "the Hubble metrics dashboard is not provisioned"
echo "$dashboards" | jq -r '.[].title' | grep -q "Hubble flows (live)" \
  || die "the embedded Hubble flow dashboard is not provisioned"

log "==> Prometheus scrape targets"
for job in hubble tetragon; do
  up="$(curl -fsS --max-time 10 -u "$GRAFANA_AUTH" -G \
    "$GRAFANA_URL/api/datasources/proxy/uid/prometheus/api/v1/query" \
    --data-urlencode "query=up{job=\"$job\"}" | jq -r '.data.result[0].value[1] // "0"')"
  echo "$job up=$up"
  [[ "$up" == "1" ]] || die "Prometheus cannot scrape the $job target"
done

log "==> Hubble metrics"
# Generate one request so the counter is non-zero, then confirm the series exists.
curl -fsS --max-time 5 "$WEB_URL/healthz" >/dev/null 2>&1 || true
sleep 2
hubble_total="$(curl -fsS --max-time 10 -u "$GRAFANA_AUTH" -G \
  "$GRAFANA_URL/api/datasources/proxy/uid/prometheus/api/v1/query" \
  --data-urlencode 'query=sum(hubble_flows_processed_total)' | jq -r '.data.result[0].value[1] // "0"')"
echo "hubble_flows_processed_total=$hubble_total"
[[ "$hubble_total" != "0" ]] || die "no Hubble flow metrics reached Prometheus"

log "==> Tetragon events in Loki"
events="$(curl -fsS --max-time 10 -u "$GRAFANA_AUTH" -G \
  "$GRAFANA_URL/api/datasources/proxy/uid/loki/loki/api/v1/query_range" \
  --data-urlencode 'query={job="tetragon"} |= "process_exec"' \
  --data-urlencode 'limit=5' \
  --data-urlencode 'since=10m' | jq -r '[.data.result[].values[]] | length')"

echo "events found: $events"
[[ "$events" -gt 0 ]] || die "no Tetragon events reached Loki; check the promtail logs"

log "==> runtime dashboard OK: $GRAFANA_URL (admin / lab-demo-password)"
