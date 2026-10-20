# Decision Records

Durable, meaningful choices. Two types:

- **ADR** — architecture decision: how the system is structured.
- **TDR** — technology decision: stack, library, provider, protocol, or tooling.

Status lifecycle: `Proposed → Accepted → Superseded | Deprecated`. ADR and TDR use separate ID sequences.

## Modes

Choose one mode per project and record the choice at adoption. The index below is used in both modes.

**Mode in use:** simple — recorded at adoption on 2026-10-19.

- **Simple (default):** entries live inline in this file. Best for small projects and up to roughly 15–20 active records.
- **Scale:** one file per record under `docs/decisions/`, named `ADR-NNN-<slug>.md` or `TDR-NNN-<slug>.md`. This file stays as the index only.

Migrate from simple to scale when the inline log gets unwieldy. Keep IDs stable during migration.

## Entry format

```text
## ADR-NNN / TDR-NNN — Title
Type: ADR | TDR
Status: Proposed | Accepted | Superseded | Deprecated
Date: YYYY-MM-DD
Owners: <who>
Supersedes: <ID or none>

Context:
...

Decision:
...

Reasoning:
...

Consequences:
...
```

## Index

| ID | Type | Title | Status | Date | File |
| --- | --- | --- | --- | --- | --- |
| ADR-001 | ADR | Single repository, shared workloads, target-specific deployments | Accepted | 2026-10-19 | inline |
| ADR-002 | ADR | Local target runs entirely inside kind/Docker | Accepted | 2026-10-19 | inline |
| ADR-003 | ADR | Cilium as primary CNI on EKS with ENI IPAM | Accepted | 2026-10-19 | inline |
| TDR-001 | TDR | Terraform for the EKS target | Accepted | 2026-10-19 | inline |
| TDR-002 | TDR | Go API, static nginx frontend, PostgreSQL | Accepted | 2026-10-19 | inline |
| TDR-003 | TDR | Pin kind 0.33.0, Kubernetes 1.35.8, Cilium 1.20.3, Tetragon 1.7.1 | Accepted | 2026-10-19 | inline |
| TDR-004 | TDR | Grafana + Loki + Promtail for Tetragon events | Accepted | 2026-10-20 | inline |

## Records

In simple mode, add entries inline here. In scale mode, keep only the index above and create files under `docs/decisions/`.

## ADR-001 — Single repository, shared workloads, target-specific deployments

Type: ADR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
The lab must run on local kind and AWS EKS without maintaining two copies of the application or policies.

Decision:
Keep `app/`, `k8s/base/`, `policies/`, `demos/`, and `scripts/` shared. Put only provisioning and per-target adjustments under `deployments/local-kind/` and `deployments/aws-eks/`.

Reasoning:
Duplication drifts; the acceptance criteria require the same scenarios on both targets.

Consequences:
Any target-specific difference must be expressed as a Kustomize overlay, Helm values file, or script flag — not by copying manifests.

## ADR-002 — Local target runs entirely inside kind/Docker

Type: ADR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
The owner requires that no runtime executes directly on the workstation. CLIs may be installed, but the application, database, CNI, and tooling workloads must run in containers.

Decision:
The local lab is a kind cluster; all workloads run as pods in Docker containers. The host only runs CLIs (`kind`, `kubectl`, `helm`, `cilium`, `docker`) and short-lived port-forward processes. No host PostgreSQL, API process, or CNI daemon is started.

Reasoning:
Reproducibility and isolation: `make down` removes the cluster and leaves no host runtime state.

Consequences:
- `make up` requires a running Docker daemon.
- Host ports are used only for explicit localhost port mappings/forwards (8080 web, 8081 Hubble UI).
- Docker image pulls can dominate first-run time; see `.ai/LEARNINGS.md`.

## ADR-003 — Cilium as primary CNI on EKS with ENI IPAM

Type: ADR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
The EKS target must demonstrate the same Cilium/Hubble/Tetragon behavior as the local target without CNI conflicts.

Decision:
Use Cilium as the primary CNI with AWS ENI IPAM (`eni.enabled=true`, `ipam.mode=eni`, `routingMode=native`). The EKS module hardcodes `bootstrap_self_managed_addons=false`; the AWS VPC CNI and kube-proxy are not installed. CoreDNS is installed after Cilium. Cilium is not combined with EKS Auto Mode or Fargate.

Reasoning:
Matches the brief and avoids two CNIs managing the same pod network.

Consequences:
Node bootstrap waits for Cilium; the operator needs an IRSA role with ENI permissions; bootstrap order must be preserved.

## TDR-001 — Terraform for the EKS target

Type: TDR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
The brief allows Terraform or OpenTofu. Only Terraform is installed on the author machine.

Decision:
Use Terraform `>= 1.6` with pinned modules `terraform-aws-modules/vpc/aws 6.7.3` and `terraform-aws-modules/eks/aws 21.29.0`, and provider `hashicorp/aws 6.69.1`.

Reasoning:
No additional toolchain, and the module versions were validated with `terraform validate`.

Consequences:
The state backend is local by default; use a remote backend before shared use.

## TDR-002 — Go API, static nginx frontend, PostgreSQL

Type: TDR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
The application only needs to prove the `frontend → API → PostgreSQL` flow and produce observable network and process events.

Decision:
Static HTML/JS served by nginx, a Go API using the standard library plus `pgx` for PostgreSQL, and the official `postgres:17-alpine` image. All images are built locally for kind and loaded with `kind load`.

Reasoning:
Small images, no Node build step, few dependencies, and clear runtime behavior for Tetragon.

Consequences:
No migration framework; the schema is initialized from a ConfigMap for the demo.

## TDR-003 — Pin kind 0.33.0, Kubernetes 1.35.8, Cilium 1.20.3, Tetragon 1.7.1

Type: TDR
Status: Accepted
Date: 2026-10-19
Owners: repository owner
Supersedes: none

Context:
Reproducible demos need fixed versions; the EKS target should use the same Kubernetes minor.

Decision:
kind `v0.33.0`, node image `kindest/node:v1.35.8`, Cilium chart `1.20.3`, Tetragon chart `1.7.1`, EKS `1.35`.

Reasoning:
Current stable releases at adoption; EKS default was 1.36 but 1.35 keeps both targets on the same minor and a Cilium-verified line.

Consequences:
Verify Cilium compatibility before bumping Kubernetes; image digests are pinned in the kind config.

## TDR-004 — Grafana + Loki + Promtail for Tetragon events

Type: TDR
Status: Accepted
Date: 2026-10-20
Owners: repository owner
Supersedes: none

Context:
Tetragon has no UI and its events are only visible through `tetra getevents`. The owner asked for a dashboard view of runtime activity.

Decision:
Install Loki (single binary, filesystem, 1 GiB), Promtail (DaemonSet tailing `/var/run/cilium/tetragon/tetragon.log` via hostPath), and Grafana with a provisioned Loki datasource and a "Tetragon runtime events" dashboard. All stay in the `observability` namespace; Grafana is reachable only through a localhost port-forward.

Reasoning:
Reuses the JSON log Tetragon already writes, adds no agent to the app pods, and keeps the host free of runtime processes. Loki + Grafana are the smallest stack that supports log search and a dashboard.

Consequences:
- Loki data is ephemeral with 24h retention; not a production logging backend.
- Sigkill enforcement events are not exported by Tetragon, so the dashboard cannot prove them; demos use the 137 exit code.
- The EKS target does not install this stack yet (see `.ai/TASKS.md`).

Do not backfill invented history. Record decisions that are observed, expressly documented, or approved during future work.

The design rationale for this template itself lives in [`docs/design.md`](../docs/design.md).
