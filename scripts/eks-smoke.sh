#!/usr/bin/env bash
# Validate the EKS deployment without exposing anything publicly: port-forward
# the web Service to localhost and run the shared smoke test.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

require_cmd kubectl curl jq

LOG_FILE="$(mktemp)"
kubectl -n ebpf-lab port-forward svc/web 8080:80 >"$LOG_FILE" 2>&1 &
forward_pid=$!

cleanup() {
  kill "$forward_pid" 2>/dev/null || true
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  if (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null; then
    exec 3>&-
    break
  fi
  sleep 1
done

WEB_URL="http://127.0.0.1:8080" "$ROOT_DIR/scripts/smoke-test.sh"
