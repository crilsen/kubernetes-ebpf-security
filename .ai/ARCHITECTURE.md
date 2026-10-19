# Architecture

## Current state

**Observed:** no application, infrastructure, deployment, or policy artifacts exist. Everything below the *Specified target architecture* heading is **specified** by `contexto.md` and is not implemented.

## Specified target architecture

### Shared content (one copy, both targets)

```text
app/            frontend, API, PostgreSQL, tests
k8s/base/       shared workloads and services
policies/
  cilium/       network policies
  tetragon/     runtime observation and enforcement
demos/          shared scenarios and validations
scripts/
evidence/       executed test results
```

### Target-specific content (never duplicated)

```text
deployments/local-kind/   cluster/ (kind config), helm/ (local values), overlay/ (local adjustments)
deployments/aws-eks/      tofu/ (Terraform or OpenTofu), helm/ (EKS values), overlay/ (EKS adjustments)
```

The split rule from the brief: share application and policies; keep only provisioning and deployment files specific to each target.

### Application flow

```text
user → frontend → API → PostgreSQL
```

Network policies constrain these paths; Hubble reports allowed and denied flows; Tetragon observes process and file activity.

### Local target (`deployments/local-kind`)

- kind cluster created by a single `make up`, which validates tools and resources first.
- **No runtime executes on the host** (owner requirement): the application, PostgreSQL, Cilium, Hubble, and Tetragon all run as pods in Docker containers. The host only runs CLIs and short-lived port-forwards.
- Installs Cilium, Hubble (Relay and UI), and Tetragon.
- Builds and loads the project's own images, deploys the application, waits for readiness, runs basic checks.
- Reports local application and Hubble addresses on success; records diagnostics and the failing step on failure.
- `make down` stops local port-forwards and removes only this POC's kind cluster.
- Blocking and enforcement scenarios run as separate commands so the baseline stays functional.

### AWS target (`deployments/aws-eks`)

- VPC, standard EKS cluster, and Linux EC2 nodes provisioned with Terraform or OpenTofu; versions pinned.
- Cilium as primary CNI using AWS ENI/IPAM unless a documented justification says otherwise.
- AWS VPC CNI handling must be explicit to avoid conflicts with Cilium.
- EKS Auto Mode and Fargate are excluded for this target.
- Version compatibility and bootstrap order validated before workloads are installed.
- `make eks-up` / `make eks-down` are separate commands. Before create or destroy: verify account, region, and environment name; show a cost estimate and the IaC plan.
- Hubble UI is not exposed publicly; access is local and restricted.
- Documentation must cover IAM requirements, CIDRs, subnets, routes, security groups, AMI, and kernel.

## Open architectural questions

1. Terraform or OpenTofu for the AWS target, and the state backend/locking choice.
2. Which Cilium and Tetragon versions are pinned, and their verified EKS/kind compatibility.
3. How the AWS VPC CNI is disabled or tainted during bootstrap.
4. Node AMI and kernel requirements for Tetragon on EKS.
5. Web UI stack for the frontend and language/framework for the API.
6. Cost ceiling and default region/instance type for the EKS demo.

Resolve each as an ADR/TDR in `.ai/DECISIONS.md` before implementing the affected part.

## Context layer

`AGENTS.md` routes to `.ai/`, which is the portable source of truth. Tool-specific adapters only point back to `AGENTS.md`.
