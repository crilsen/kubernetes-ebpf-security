#!/usr/bin/env bash
# Provision the EKS target and install Cilium, Tetragon, and the application.
# Paid resources: this script always shows account, region, cluster, cost estimate,
# and the IaC plan, then requires explicit confirmation.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

TF_DIR="$ROOT_DIR/deployments/aws-eks/tofu"
CLUSTER_NAME="${CLUSTER_NAME:-ebpf-lab}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
TETRAGON_VERSION="${TETRAGON_VERSION:-1.7.1}"
RUN_DIR="$ROOT_DIR/.run"

export AWS_REGION
export TF_IN_AUTOMATION=1

STEP="preflight"
trap 'print_failure_context "$STEP"' ERR
step() { STEP="$1"; log "==> $1"; }

step "check required tools"
require_cmd aws terraform helm kubectl jq
mkdir -p "$RUN_DIR"

step "verify AWS identity and target"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
log "account : $ACCOUNT_ID"
log "caller  : $CALLER_ARN"
log "region  : $AWS_REGION"
log "cluster : $CLUSTER_NAME"
log ""
log "Estimated cost with default sizes (us-east-1, 2x t3.medium, single NAT):"
log "  EKS control plane \$73.00/mo + workers \$60.74/mo + NAT \$32.85/mo + EBS ~\$3.20/mo"
log "  Rough total: ~\$169.79/mo (~\$0.23/h). AWS pricing changes; verify before applying."
log ""

if [[ "${ASSUME_YES:-}" != "1" ]]; then
  confirm "Create paid AWS resources in account $ACCOUNT_ID ($AWS_REGION)?" \
    || die "aborted by the operator"
fi

step "terraform init"
terraform -chdir="$TF_DIR" init -input=false

step "terraform plan"
terraform -chdir="$TF_DIR" plan -input=false -out=tfplan
log ""
log "Review the plan above. It creates a VPC, EKS cluster, managed nodes, and IAM roles."
if [[ "${ASSUME_YES:-}" != "1" ]]; then
  confirm "Apply this plan?" || die "aborted by the operator"
fi

step "terraform apply"
terraform -chdir="$TF_DIR" apply -input=false tfplan

step "update kubeconfig"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null

CLUSTER_ENDPOINT="$(terraform -chdir="$TF_DIR" output -raw cluster_endpoint)"
K8S_HOST="${CLUSTER_ENDPOINT#https://}"
ROLE_ARN="$(terraform -chdir="$TF_DIR" output -raw cilium_operator_role_arn)"

step "install Cilium $CILIUM_VERSION (ENI IPAM, kube-proxy replacement)"
helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update cilium >/dev/null

OVERRIDE="$RUN_DIR/cilium-eks-values.yaml"
cat >"$OVERRIDE" <<EOF
cluster:
  name: ${CLUSTER_NAME}
k8sServiceHost: ${K8S_HOST}
k8sServicePort: 443
serviceAccounts:
  operator:
    annotations:
      eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --values "$ROOT_DIR/deployments/aws-eks/helm/cilium-values.yaml" \
  --values "$OVERRIDE" \
  --wait --timeout 15m

step "install CoreDNS (skipped during node bootstrap because Cilium owns the CNI)"
if aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --addon-name coredns >/dev/null 2>&1; then
  aws eks update-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --addon-name coredns --resolve-conflicts OVERWRITE >/dev/null
else
  aws eks create-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --addon-name coredns --resolve-conflicts OVERWRITE >/dev/null
fi
aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --addon-name coredns

step "wait for nodes to become Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=15m

step "install Tetragon $TETRAGON_VERSION"
helm repo add tetragon https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update tetragon >/dev/null
helm upgrade --install tetragon cilium/tetragon \
  --namespace kube-system \
  --version "$TETRAGON_VERSION" \
  --values "$ROOT_DIR/deployments/aws-eks/helm/tetragon-values.yaml" \
  --wait --timeout 15m

step "deploy the application"
kubectl apply -k "$ROOT_DIR/deployments/aws-eks/overlay"
kubectl -n ebpf-lab rollout status deployment/postgres --timeout=10m
kubectl -n ebpf-lab rollout status deployment/api --timeout=10m
kubectl -n ebpf-lab rollout status deployment/web --timeout=10m

step "apply the same policies used locally"
kubectl apply -f "$ROOT_DIR/policies/cilium/baseline"
kubectl apply -f "$ROOT_DIR/policies/tetragon/observe-exec.yaml"

step "run the smoke test through a local port-forward"
"$ROOT_DIR/scripts/eks-smoke.sh"

log ""
log "EKS lab is ready."
log "  kubectl context : $(kubectl config current-context)"
log "  Application     : make eks-smoke (local port-forward only)"
log "  Hubble UI       : kubectl -n kube-system port-forward svc/hubble-ui 8081:80"
log "  Teardown        : make eks-down"
