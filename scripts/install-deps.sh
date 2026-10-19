#!/usr/bin/env bash
# Install or verify the local CLIs used by the lab. This never installs or
# starts a runtime: Docker must already be installed and running.
#
# Usage:
#   ./scripts/install-deps.sh          # install missing CLIs (Homebrew on macOS)
#   ./scripts/install-deps.sh --check  # only report; exit 1 if required CLIs are missing
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

REQUIRED=(docker kind kubectl helm jq curl git)
OPTIONAL=(cilium hubble shellcheck terraform aws go)

# formula name -> binary name
formula_for() {
  case "$1" in
    cilium) echo "cilium-cli" ;;
    kubectl) echo "kubernetes-cli" ;;
    aws) echo "awscli" ;;
    go) echo "go" ;;
    *) echo "$1" ;;
  esac
}

missing_required=()
missing_optional=()
for cmd in "${REQUIRED[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing_required+=("$cmd")
done
for cmd in "${OPTIONAL[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing_optional+=("$cmd")
done

if [[ ${#missing_required[@]} -eq 0 && ${#missing_optional[@]} -eq 0 ]]; then
  log "all local dependencies are installed"
  exit 0
fi

if [[ ${#missing_required[@]} -gt 0 ]]; then
  warn "missing required: ${missing_required[*]}"
else
  log "required dependencies present"
fi
if [[ ${#missing_optional[@]} -gt 0 ]]; then
  log "missing optional: ${missing_optional[*]} (needed for demos or the EKS target)"
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  [[ ${#missing_required[@]} -eq 0 ]] && exit 0
  die "install the missing CLIs with: make deps"
fi

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  log ""
  log "Automatic installation is implemented for macOS (Homebrew) only."
  log "On Linux, install the missing tools with your package manager, for example:"
  log "  kind:      https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
  log "  kubectl:   https://kubernetes.io/docs/tasks/tools/"
  log "  helm:      https://helm.sh/docs/intro/install/"
  log "  cilium:    https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli"
  log "  hubble:    https://docs.cilium.io/en/stable/observability/hubble/setup/"
  die "install the missing tools, then re-run: ./scripts/install-deps.sh --check"
fi

command -v brew >/dev/null 2>&1 || die "Homebrew is required for automatic installation: https://brew.sh"

for cmd in "${missing_required[@]}" "${missing_optional[@]}"; do
  if [[ "$cmd" == "docker" ]]; then
    log ""
    warn "Docker is not installed. Install Docker Desktop (or another daemon) manually:"
    warn "  https://docs.docker.com/desktop/install/mac-install/"
    continue
  fi
  formula="$(formula_for "$cmd")"
  log "installing $cmd ($formula)"
  brew install "$formula"
done

log ""
log "verifying dependencies"
"$ROOT_DIR/scripts/install-deps.sh" --check || die "dependencies are still missing after installation"
log "done. Start Docker Desktop before running: make up"
