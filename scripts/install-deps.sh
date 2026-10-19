#!/usr/bin/env bash
# Install or verify the local CLIs used by the lab. This never installs or
# starts a runtime: Docker must already be installed and running.
#
# Usage:
#   ./scripts/install-deps.sh          # install missing CLIs (macOS or Ubuntu/WSL)
#   ./scripts/install-deps.sh --check  # only report; exit 1 if required CLIs are missing
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

# Versions stay aligned with the project pins (see .ai/DECISIONS.md TDR-003).
KIND_VERSION="0.33.0"
KUBECTL_VERSION="1.35.8"
HELM_VERSION="4.3.0"
CILIUM_CLI_VERSION="0.20.1"
HUBBLE_VERSION="1.20.2"
TERRAFORM_VERSION="1.16.1"

REQUIRED=(docker kind kubectl helm jq curl git)
OPTIONAL=(cilium hubble shellcheck terraform aws go)

# formula name -> binary name (macOS)
formula_for() {
  case "$1" in
    cilium) echo "cilium-cli" ;;
    kubectl) echo "kubernetes-cli" ;;
    aws) echo "awscli" ;;
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
  log "missing optional: ${missing_optional[*]} (needed for demos, dev checks, or the EKS target)"
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  [[ ${#missing_required[@]} -eq 0 ]] && exit 0
  die "install the missing CLIs with: make deps"
fi

need() {
  ! command -v "$1" >/dev/null 2>&1
}

install_macos() {
  command -v brew >/dev/null 2>&1 || die "Homebrew is required for automatic installation: https://brew.sh"

  for cmd in "${missing_required[@]}" "${missing_optional[@]}"; do
    if [[ "$cmd" == "docker" ]]; then
      log ""
      warn "Docker is not installed. Install Docker Desktop manually:"
      warn "  https://docs.docker.com/desktop/install/mac-install/"
      continue
    fi
    formula="$(formula_for "$cmd")"
    log "installing $cmd ($formula)"
    brew install "$formula"
  done
}

install_linux_ubuntu() {
  if [[ ! -r /etc/os-release ]]; then
    die "cannot identify the distribution (missing /etc/os-release)"
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-} ${ID_LIKE:-}" in
    *ubuntu* | *debian*) ;;
    *) die "automatic installation supports Ubuntu/Debian (and WSL) only; install the CLIs manually" ;;
  esac

  if grep -qi microsoft /proc/version 2>/dev/null; then
    log "WSL detected"
  fi

  SUDO=()
  [[ $EUID -ne 0 ]] && SUDO=(sudo)

  log "installing base packages with apt"
  "${SUDO[@]}" apt-get update -y
  # shellcheck disable=SC2068
  "${SUDO[@]}" apt-get install -y --no-install-recommends \
    curl ca-certificates git jq shellcheck unzip tar

  case "$(uname -m)" in
    x86_64 | amd64) ARCH="amd64" ; AWS_ARCH="x86_64" ;;
    aarch64 | arm64) ARCH="arm64" ; AWS_ARCH="aarch64" ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac

  if need kubectl; then
    log "installing kubectl v$KUBECTL_VERSION"
    tmp="$(mktemp)"
    curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp" /usr/local/bin/kubectl
    rm -f "$tmp"
  fi

  if need kind; then
    log "installing kind v$KIND_VERSION"
    tmp="$(mktemp)"
    curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${ARCH}" -o "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp" /usr/local/bin/kind
    rm -f "$tmp"
  fi

  if need helm; then
    log "installing helm v$HELM_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz" | tar -xz -C "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp/linux-${ARCH}/helm" /usr/local/bin/helm
    rm -rf "$tmp"
  fi

  if need cilium; then
    log "installing cilium-cli v$CILIUM_CLI_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz" | tar -xz -C "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp/cilium" /usr/local/bin/cilium
    rm -rf "$tmp"
  fi

  if need hubble; then
    log "installing hubble v$HUBBLE_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-${ARCH}.tar.gz" | tar -xz -C "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp/hubble" /usr/local/bin/hubble
    rm -rf "$tmp"
  fi

  if need terraform; then
    log "installing terraform v$TERRAFORM_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" -o "$tmp/terraform.zip"
    unzip -q -o "$tmp/terraform.zip" -d "$tmp"
    "${SUDO[@]}" install -m 0755 "$tmp/terraform" /usr/local/bin/terraform
    rm -rf "$tmp"
  fi

  if need aws; then
    log "installing AWS CLI v2"
    tmp="$(mktemp -d)"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "$tmp/awscliv2.zip"
    unzip -q -o "$tmp/awscliv2.zip" -d "$tmp"
    "${SUDO[@]}" "$tmp/aws/install" --update
    rm -rf "$tmp"
  fi

  if need docker; then
    log ""
    warn "Docker is not installed. Install Docker Engine or Docker Desktop manually:"
    warn "  https://docs.docker.com/engine/install/ubuntu/"
    warn "  WSL: enable Docker Desktop WSL integration, or install Docker Engine inside the distro."
  fi

  if need go; then
    log "Go is not installed automatically (the project needs Go 1.27+):"
    log "  https://go.dev/dl/"
  fi
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux) install_linux_ubuntu ;;
  *) die "unsupported operating system: $(uname -s)" ;;
esac

log ""
log "verifying dependencies"
"$ROOT_DIR/scripts/install-deps.sh" --check || die "dependencies are still missing; install Docker if that is the only gap"
log "done. Start Docker before running: make up"
