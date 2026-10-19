#!/usr/bin/env bash
# Shared helpers for the lab scripts. Source this file, do not execute it.

log()  { printf '[lab] %s\n' "$*"; }
warn() { printf '[lab] WARNING: %s\n' "$*" >&2; }
die()  { printf '[lab] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
  done
}

# confirm <prompt>: returns 0 only for an explicit "yes".
confirm() {
  local answer
  printf '%s [y/N] ' "$1"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "yes" ]]
}

# run_with_timeout <seconds> <command...>
# Portable timeout: macOS does not ship `timeout` by default.
run_with_timeout() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  else
    "$@" &
    local pid=$!
    ( sleep "$seconds"; kill -TERM "$pid" 2>/dev/null ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local status=$?
    kill "$watcher" 2>/dev/null || true
    return "$status"
  fi
}

print_failure_context() {
  local step="$1"
  printf '\n[lab] FAILED at: %s\n' "$step" >&2
  printf '[lab] Inspect the message above; the environment was left in place for debugging.\n' >&2
  printf '[lab] Re-run the same command after fixing the cause, or run "make down" to remove the local cluster.\n' >&2
}
