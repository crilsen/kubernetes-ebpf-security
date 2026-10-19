#!/usr/bin/env bash
# Destroy the EKS target. Shows the plan and requires explicit confirmation.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

TF_DIR="$ROOT_DIR/deployments/aws-eks/tofu"
CLUSTER_NAME="${CLUSTER_NAME:-ebpf-lab}"
AWS_REGION="${AWS_REGION:-us-east-1}"

export AWS_REGION
export TF_IN_AUTOMATION=1

STEP="preflight"
trap 'print_failure_context "$STEP"' ERR
step() { STEP="$1"; log "==> $1"; }

step "check required tools"
require_cmd aws terraform

step "verify AWS identity and target"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
log "account : $ACCOUNT_ID"
log "region  : $AWS_REGION"
log "cluster : $CLUSTER_NAME"
log ""
log "This destroys the VPC, EKS cluster, nodes, and NAT gateway for this lab."
log "It does not touch resources outside this Terraform state."
if [[ "${ASSUME_YES:-}" != "1" ]]; then
  confirm "Destroy the resources for cluster $CLUSTER_NAME in account $ACCOUNT_ID?" \
    || die "aborted by the operator"
fi

step "terraform plan -destroy"
terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" plan -destroy -input=false -out=destroy.tfplan

step "terraform destroy"
terraform -chdir="$TF_DIR" apply -input=false destroy.tfplan

rm -f "$TF_DIR/destroy.tfplan" "$TF_DIR/tfplan"

log "EKS target destroyed. Verify in the AWS console that no lab resources remain."
