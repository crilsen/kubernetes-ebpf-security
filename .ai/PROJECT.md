# Project

## Identity

- **Name:** kubernetes-ebpf-security-lab
- **Objective:** A portfolio lab that demonstrates network and runtime security and observability in Kubernetes with Cilium, Hubble, and Tetragon.
- **Repository shape:** One repository with the application, policies, and scenarios shared between two independent deployment targets: local kind and AWS EKS.
- **Status:** Context adopted, no implementation. The repository contains only `AGENTS.md`, `contexto.md`, and `.ai/`.

## Observed

- The directory is **not** a Git repository (`git status` → `not a git repository`) as of 2026-10-19.
- No application source, Kubernetes manifests, policies, IaC, scripts, CI/CD, or tests exist yet.
- `contexto.md` (Portuguese) is the implementation brief supplied by the repository owner. It is the only source of scope.
- Local tooling observed on the author machine: `git`, `docker` 29.7.2, `kubectl` v1.35.7 (Google Cloud SDK build), `helm` v4.3.0, `terraform` v1.16.1, `aws` CLI 2.36.44, `jq`, `shellcheck`, `node`, `npm`, `python3`. **Missing:** `kind`, `cilium` CLI, `tofu`, `yq`.

## Specified scope (from `contexto.md`, not yet implemented)

- **Cilium** as CNI and workload connectivity policy engine.
- **Hubble** with Relay and UI for allowed and denied flow visibility.
- **Tetragon** for process and file-access events; observation first, controlled enforcement only in a dedicated workload.
- **Application:** frontend → API → PostgreSQL.
- **Scenarios:** functional baseline, microsegmentation, flow analysis, runtime observation and enforcement, troubleshooting and recovery.
- **Local target:** `make up` / `make down`, kind cluster, one-command bootstrap and teardown.
- **AWS target:** VPC, standard EKS cluster, and Linux EC2 nodes provisioned with Terraform or OpenTofu; Cilium as primary CNI with AWS ENI/IPAM; `make eks-up` / `make eks-down`.

## Non-goals (specified)

- Cluster Mesh, a second cloud provider, and production readiness are roadmap items outside the initial scope.
- Demo scenarios must not be presented as production configuration or as generic protection against any access.

## Context maintenance

- **Automatic** (owner choice, 2026-10-19): keep `.ai/` current as work happens.
- **Annotation language:** English (code comments and relay `.md` files).
- When the brief and the code disagree, record the difference instead of silently rewriting the brief.
