#!/usr/bin/env bash
# Validate the baseline: web reachable, web -> api -> postgres working.
set -Eeuo pipefail

WEB_URL="${WEB_URL:-http://127.0.0.1:8080}"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

echo "[smoke] waiting for $WEB_URL/healthz"
ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 "$WEB_URL/healthz" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == "1" ]] || { echo "[smoke] frontend did not become ready at $WEB_URL" >&2; exit 1; }

echo "[smoke] frontend page responds"
curl -fsS --max-time 5 "$WEB_URL/" | grep -q "Kubernetes eBPF Security Lab"

echo "[smoke] API reaches PostgreSQL through Cilium policy"
payload="$(curl -fsS --max-time 10 "$WEB_URL/api/message")"
echo "$payload" | jq .

echo "$payload" | jq -e '.database.connected == true' >/dev/null \
  || { echo "[smoke] API reported the database as unreachable" >&2; exit 1; }

echo "[smoke] PASS: baseline frontend -> API -> PostgreSQL works"
