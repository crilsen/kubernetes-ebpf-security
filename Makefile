SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ROOT := $(abspath .)
TOFU_DIR := $(ROOT)/deployments/aws-eks/tofu

.PHONY: help deps deps-check up down restart smoke demo-list demo-baseline demo-microsegmentation demo-observe demo-enforce demo-denied demo-multicontainer lint fmt verify eks-plan eks-up eks-down eks-smoke

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install or verify the local CLIs (Docker must be installed separately)
	./scripts/install-deps.sh

deps-check: ## Report missing local CLIs without installing anything
	./scripts/install-deps.sh --check

up: ## Create the local kind lab, install Cilium/Hubble/Tetragon, deploy the app
	./scripts/local-up.sh

down: ## Remove port-forwards and the local kind cluster
	./scripts/local-down.sh

restart: down up ## Recreate the local lab from scratch

smoke: ## Validate the local baseline (frontend -> API -> PostgreSQL)
	./scripts/smoke-test.sh

demo-list: ## List the demo scenarios
	@printf '  %-28s %s\n' \
		'make demo-baseline' 'allowed flow through Cilium and Hubble' \
		'make demo-microsegmentation' 'probe pod denied by default-deny' \
		'make demo-observe' 'Tetragon process observation' \
		'make demo-enforce' 'Tetragon shell-exec enforcement in a dedicated pod' \
		'make demo-denied' 'live Cilium deny: browser gets 504, Hubble shows DROPPED' \
		'make demo-multicontainer' '3 containers in one pod: enforcement + port-level deny'

demo-baseline: ## Scenario 1: functional baseline and allowed flows
	./demos/01-baseline.sh

demo-microsegmentation: ## Scenario 2: default-deny blocks a probe pod
	./demos/02-microsegmentation.sh

demo-observe: ## Scenario 3: Tetragon process observation (no enforcement)
	./demos/03-runtime-observe.sh

demo-enforce: ## Scenario 4: Tetragon enforcement in a dedicated namespace
	./demos/04-runtime-enforce.sh

demo-denied: ## Scenario 5: live deny visible from the browser (504 + DROPPED flow)
	./demos/05-denied-endpoint.sh

demo-multicontainer: ## Scenario 6: 3 containers in one pod, enforcement and port-level deny
	./demos/06-multicontainer.sh

lint: ## Static checks available without a cluster
	shellcheck scripts/*.sh scripts/lib/*.sh demos/*.sh
	cd app/api && go vet ./... && go test ./...
	kubectl kustomize deployments/local-kind/overlay >/dev/null
	kubectl kustomize deployments/aws-eks/overlay >/dev/null

fmt: ## Format Go and Terraform sources
	cd app/api && gofmt -w .
	terraform fmt -recursive $(TOFU_DIR)

verify: lint ## Run every check that does not require a cluster
	terraform -chdir=$(TOFU_DIR) fmt -check -recursive
	terraform -chdir=$(TOFU_DIR) validate

eks-plan: ## Show the AWS plan without applying it
	terraform -chdir=$(TOFU_DIR) init -input=false
	terraform -chdir=$(TOFU_DIR) plan -input=false

eks-up: ## Provision the EKS target (paid resources; asks for confirmation)
	./scripts/eks-up.sh

eks-down: ## Destroy the EKS target (asks for confirmation)
	./scripts/eks-down.sh

eks-smoke: ## Validate the EKS deployment through a local port-forward
	./scripts/eks-smoke.sh
