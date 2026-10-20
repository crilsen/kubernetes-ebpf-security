# Run 2026-10-20 — multi-container scenario

## Environment

Same kind cluster as `evidence/2026-10-19-local-baseline/` (Kubernetes 1.35.8, Cilium 1.20.3, Tetragon 1.7.1).

## Topology

One pod (`stack`) in namespace `ebpf-lab-mc` with three containers sharing the pod network namespace:

| Container | Image | Port | Role |
| --- | --- | --- | --- |
| `front` | `ebpf-lab/web:dev` (nginx) | 8080 | Entry point; proxies to localhost |
| `back` | `ebpf-lab/api:dev` | 8081 | Backend, exposes `/policy-sim` |
| `api` | `ebpf-lab/api:dev` | 8082 | API container, blocked from outside |

## Command and results

Command: `make demo-multicontainer` (see [`demo-06-multicontainer.log`](demo-06-multicontainer.log)).

Expected and observed:

| Check | Expected | Observed |
| --- | --- | --- |
| `front → back` and `front → api` over localhost | Reachable | `{"status":"ok"}` from both |
| `/policy-sim` | Simulated 403, no packet dropped | HTTP 403 with `"simulated": true` |
| Shell exec in `front`, `back`, `api` | SIGKILL in every container | Exit 137 in all three |
| `probe → stack:8080` | Allowed | HTTP 200 |
| `probe → stack:8081` and `:8082` | Denied by Cilium | Timeout; Hubble `INGRESS DENIED` / `DROPPED` |
| Cleanup | Namespace and policy removed | Namespace terminating; policy gone |

## Findings

1. **Cilium selects pods, not containers.** The deny on 8081/8082 works because each container listens on a distinct pod port; a policy between containers of the same pod is not expressible at L3/L4.
2. **Intra-pod traffic never reaches the policy datapath.** Localhost traffic between containers bypasses Cilium and does not appear in Hubble.
3. **Tetragon selects the pod and applies to all containers.** One `TracingPolicy` covered `front`, `back`, and `api`.
4. **`/policy-sim` is explicitly application-level.** It returns 403 without dropping any packet and must not be presented as network enforcement.

## Scope notes

- The scenario is self-contained in `ebpf-lab-mc` and is removed after the run.
- Use `KEEP=1 make demo-multicontainer` to keep it and port-forward the front at `:8090`.
