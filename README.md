# Kubernetes eBPF Security

A portfolio lab for network and runtime security in Kubernetes with **Cilium**, **Hubble**, and **Tetragon**. One repository, one application, two deployment targets:

| Target | Purpose | Entry points |
| --- | --- | --- |
| **Local (kind)** | Fast, disposable lab for development and demos | `make up` / `make down` |
| **AWS EKS** | Cloud deployment with its own networking, IAM, and cost profile | `make eks-up` / `make eks-down` |

The application and the policies are shared. Only provisioning and deployment files differ per target.

```text
user → web (nginx) → api (Go) → postgres
              │          │          │
              └──────────┴──────────┴── Cilium network policy + Hubble flows
                                  Tetragon process events
```

## What the lab demonstrates

1. **Functional baseline** — `make up` builds the lab, deploys the app, and proves `web → api → postgres` works.
2. **Microsegmentation** — a pod in the same namespace is denied by default, while the intended path is allowed.
3. **Flow visibility** — Hubble shows allowed and dropped flows with policy verdicts.
4. **Runtime observation** — Tetragon reports process execution without blocking anything.
5. **Controlled enforcement** — a dedicated workload kills shell execution; the baseline is untouched.
6. **Denied endpoint** — the browser calls a Service with no allow rule, gets a 504, and Hubble shows the dropped flow.
7. **Multi-container pod** — `front`, `back`, and `api` in one pod: external deny by container port, localhost traffic that Cilium cannot filter, and Tetragon enforcement in every container.
8. **Runtime dashboard** — Grafana + Loki show Tetragon process events per namespace, pod, and container.

The demo policies are deliberately narrow and use fictitious data. They are not a production security baseline.

## Repository layout

```text
app/                         frontend, API, PostgreSQL init
k8s/base/                    shared workloads and services
policies/cilium/baseline/    default-deny + explicit allow rules
policies/tetragon/           observation policy + enforcement demo
demos/                       executable scenarios
deployments/local-kind/      kind config, Helm values, Kustomize overlay
deployments/aws-eks/         Terraform, Helm values, Kustomize overlay
scripts/                     bootstrap, teardown, smoke tests
evidence/                    recorded validation runs
.ai/                         portable agent context
```

## Prerequisites

**Local target:** Docker (8 GB+ recommended), `kind` ≥ 0.30, `kubectl`, `helm` ≥ 3, `jq`, and ideally the `cilium` and `hubble` CLIs.

On macOS (Homebrew) and Ubuntu/WSL (apt plus the official binaries), install the CLIs with:

```bash
make deps        # installs missing kind, kubectl, helm, cilium-cli, hubble, jq, ...
make deps-check  # only reports what is missing
```

`make up` only verifies them and asks you to run `make deps` when something is missing.

Docker is not installed by the script: install and start Docker Desktop (or Docker Engine on Ubuntu/WSL) manually.

Only CLIs run on the host. The application, database, Cilium, Hubble, and Tetragon run inside the kind cluster (Docker containers); the host keeps no runtime state after `make down`.

**EKS target:** everything above plus `terraform` ≥ 1.6, AWS CLI v2, and credentials allowed to create VPC/EKS/IAM resources.

The lab pins: kind `v0.33.0`, Kubernetes `v1.35.8`, Cilium `1.20.3`, Tetragon `1.7.1`, EKS `1.35`. Confirm Cilium's supported Kubernetes versions before changing these.

## Quick start (local)

```bash
make deps   # first time: install the CLIs (Docker is manual)
make up
```

`make up` only checks the dependencies; installation stays in `make deps`.

The command validates prerequisites, creates the kind cluster, installs Cilium (kube-proxy replacement), Hubble, and Tetragon, builds and loads the images, deploys the app, applies the baseline policies, waits for readiness, and runs the smoke test.

Then:

- Application: <http://127.0.0.1:8080>
- API (direct): <http://127.0.0.1:8082/api/message>
- Hubble UI: <http://127.0.0.1:8081>
- Runtime dashboard (Grafana): <http://127.0.0.1:3001> — `admin` / `lab-demo-password`
- Hubble Relay: `127.0.0.1:4245` for `hubble observe --server 127.0.0.1:4245`

`make up` prints this endpoint list again at the end of every run.

## Runtime dashboard (Grafana + Loki)

`make up` also installs Loki, Promtail, and Grafana in the `observability` namespace. Promtail tails `/var/run/cilium/tetragon/tetragon.log` on each node and ships the JSON events to Loki. Grafana is provisioned with the Loki datasource and the **Tetragon runtime events** dashboard.

- Grafana: <http://127.0.0.1:3001> (`admin` / `lab-demo-password`)
- Dashboard: folder **Tetragon** → **Tetragon runtime events**
- Variable `namespace`: `ebpf-lab` or `ebpf-lab-mc`
- Validate: `make obs-check`

What it shows: Tetragon `process_exec`/`process_exit` events per namespace, pod, and container, plus event rates.

What it does **not** show:
- network allow/deny — use the Hubble UI;
- Sigkill enforcement events — Tetragon does not export them in this setup; the demo proves them by the `137` exit code.

Loki runs as a single binary with a 1 GiB volume and 24h retention; the data is demo-only and disappears with the cluster.

```bash
make demo-list
make demo-baseline
make demo-microsegmentation
make demo-observe
make demo-enforce
make demo-denied
make demo-multicontainer
make down
```

`make down` stops the local port-forwards and deletes only the `ebpf-lab` kind cluster.

## AWS EKS target

`deployments/aws-eks/tofu` provisions:

- a VPC with two private and two public subnets and a single NAT gateway (cost control);
- a standard EKS cluster with **no AWS VPC CNI and no kube-proxy** (`bootstrap_self_managed_addons = false`);
- a managed node group with Amazon Linux 2023 nodes;
- an IRSA role for `cilium-operator` with the EC2 permissions required by ENI IPAM.

Cilium is installed as the primary CNI with AWS ENI IPAM and kube-proxy replacement. CoreDNS is installed after Cilium. The Hubble UI is never exposed publicly; use a local port-forward.

```bash
make eks-plan     # init + plan only
make eks-up       # plan + apply + install + smoke test; asks for confirmation
make eks-smoke    # validate through a local port-forward
make eks-down     # destroy; asks for confirmation
```

`eks-up` prints the AWS account, region, cluster name, and a cost estimate before applying. With the default sizes (2× `t3.medium`, single NAT, us-east-1) the estimate is roughly **US$170/month**. Destroy the target when you are done.

### Local vs EKS

| Concern | Local kind | AWS EKS |
| --- | --- | --- |
| CNI | Cilium (Kubernetes IPAM) | Cilium (AWS ENI IPAM) |
| kube-proxy | Replaced by Cilium | Not installed; replaced by Cilium |
| App exposure | NodePort `30080` mapped to host `8080` | ClusterIP + local port-forward only |
| Observability | Hubble UI + Grafana/Loki (local only) | Cilium/Tetragon installed; no dashboard stack yet |
| IaC | kind config + Helm values | Terraform + Helm values |
| Teardown | `make down` | `make eks-down` |

## Validation

```bash
make lint      # shellcheck, go vet/test, kustomize builds
make verify    # lint + terraform fmt/validate
make smoke     # local end-to-end check
make obs-check # Grafana health, dashboard provisioning, and Tetragon events in Loki
```

Record real runs under `evidence/YYYY-MM-DD-<target>-<scenario>/`. Nothing is marked passed before it runs; see [`evidence/README.md`](evidence/README.md).

## Troubleshooting

- **First run is slow.** Pulling Cilium/Tetragon images from `quay.io` inside kind can take tens of minutes. Later runs are fast. If a pull is interrupted, `make up` clears a `pending-*` Helm release automatically before reinstalling.
- **Docker not running / low memory.** Start Docker Desktop and give it at least ~8 GB.
- **Ports 8080/8081 busy.** Stop the other process or override `WEB_PORT` for the smoke test.
- **Tetragon shows no events.** The local values enable the containerd CRI socket and `cgidmap`; both are required for pod/namespace association on kind. If events show only node names after cluster recreation or upgrades, reinstall the release (`helm uninstall tetragon -n kube-system`, then `make up`).
- **Hubble shows L3/L4 but no HTTP.** HTTP parsing requires an L7 policy; the baseline demo deliberately shows L3/L4 flows.

## Known limitations

- Demo-only credentials live in the manifests. Never reuse them.
- Grafana uses the same demo password and serves over localhost port-forward only.
- Loki stores data in a 1 GiB volume with 24h retention; it is not a production logging backend.
- Tetragon enforcement covers a single, dedicated workload; it is not a general anti-shell control.
- The local target was validated with warm image caches; a cold first run depends on registry throughput.
- Cilium/Tetragon/EKS version compatibility must be rechecked when versions change.
- The EKS target is scaffolded and passes `terraform validate`, but it has not been applied or validated against AWS. It uses a single NAT gateway and creates paid resources; destroy it after use.
- Cluster Mesh, multi-cloud, and production hardening are out of scope.

## Agent context

Work state and decisions live in `.ai/` (see `AGENTS.md`). Start with `.ai/HANDOFF.md` and `.ai/TASKS.md`.
