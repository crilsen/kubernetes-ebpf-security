# Run 2026-10-19 — local target (kind)

## Environment

See [`versions.txt`](versions.txt). Host: macOS (Darwin 25.2.0, arm64), Docker 29.7.2, kind 0.33.0, Kubernetes 1.35.8, Cilium chart 1.20.3, Tetragon chart 1.7.1, Helm 4.3.0.

The cluster runs entirely in Docker (kind nodes); the host only ran CLIs and port-forwards.

## Commands and results

### `make up` — Partially validated

Expected: create the kind cluster, install Cilium/Hubble/Tetragon, build and load images, deploy the app, apply baseline policies, wait for readiness, pass the smoke test, and expose the Hubble UI locally.

Observed:
- The first attempt was interrupted by the agent's own 25-minute command timeout while images were being pulled from `quay.io` inside the cluster (the pull phase took ~30 minutes on this network). Helm was left in `pending-install`.
- After clearing the pending release, the run completed: Cilium `OK`, Tetragon `2/2`, application pods `Running`, baseline smoke test `PASS`. See [`make-up.log`](make-up.log).
- A second run with everything cached completed without intervention and reused the cluster; see [`make-up-idempotent.log`](make-up-idempotent.log) and [`status.txt`](status.txt).
- **Not validated:** a single uninterrupted `make up` on a cold, empty Docker/kind cache. The scripts now clear `pending-*` Helm releases automatically, but the cold-pull duration remains an environmental risk.

### `make smoke` — Passed

Expected: frontend reachable, `web → api → postgres` works through Cilium policy.

Observed: HTTP 200 on `/healthz`, frontend page served, API returned `"database.connected": true`. See [`smoke.log`](smoke.log).

### `make demo-baseline` — Passed

Expected: baseline request succeeds and Hubble shows allowed flows.

Observed: API response with database data; Hubble shows `policy-verdict:L3-L4 INGRESS ALLOWED` for `web → api` and forwarded `api → postgres:5432`. See [`demo-01-baseline.log`](demo-01-baseline.log).

### `make demo-microsegmentation` — Passed

Expected: `web → api` works; an unlabeled probe pod cannot reach `api`.

Observed: `web` got `{"status":"ok"}`; the probe timed out after 5s; Hubble shows `policy-verdict:none EGRESS DENIED` and `Policy denied DROPPED` for `probe → api:8080`. See [`demo-02-microsegmentation.log`](demo-02-microsegmentation.log).

### `make demo-observe` — Passed

Expected: Tetragon reports process execution in `ebpf-lab` without blocking it.

Observed: events include `🚀 process ebpf-lab/api-... /bin/ls /` and PostgreSQL `pg_isready` executions. See [`demo-03-observe.log`](demo-03-observe.log).

### `make demo-enforce` — Passed

Expected: a dedicated workload is protected by a SIGKILL policy; the baseline is untouched.

Observed: `kubectl exec ... /bin/sh` terminated with exit code 137 (SIGKILL); the policy and target namespace were removed afterwards. See [`demo-04-enforce.log`](demo-04-enforce.log).

## Findings that changed the code

1. **Tetragon needs CRI + cgroup ID mapping on kind.** Without `tetragon.cri.enabled`, `cgidmap.enabled`, and the containerd socket, events had no pod/namespace association and namespace filters returned nothing.
2. **Tetragon `matchArgs` has no `In` operator.** The enforcement policy uses one `Equal` selector per shell path.
3. **Hubble HTTP parsing needs an L7 policy.** The baseline demo shows L3/L4 flows instead.
4. **macOS lacks `timeout`.** Scripts use a portable `run_with_timeout` helper.
5. **Helm can be left `pending-install` by a slow pull.** `local-up.sh` now reconciles pending releases before installing.

## Scope notes

- Demo-only credentials are in the manifests; do not reuse them.
- The EKS target was not applied or validated in this run.
