# Learnings

Append-only buffer of reusable, non-obvious learnings captured while working, so future sessions and tools do not rediscover them. This is not task state (`TASKS.md`), not a session handoff (`HANDOFF.md`), and not a durable decision record (`DECISIONS.md`).

## How to use

- Append one entry per learning. Do not rewrite or delete entries; to correct one, mark it `superseded` and add a new entry.
- Capture only learnings that are non-obvious and likely to recur. Skip anything already stated in `CONVENTIONS.md`, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md`.
- Keep each entry short and evidence-based. Prefer `observed` facts over speculation.
- This file is a buffer, not a permanent home: promote durable learnings and keep the entry as a breadcrumb.

## Entry format

```text
### L-001 — <short title>
Date: YYYY-MM-DD
Status: active | superseded | promoted
Confidence: observed | inferred
Scope: repo | <path-or-glob> | <technology>
Context: <what was being done>
Evidence: <file:line, command output, or concrete observation>
Pattern / rule: <the reusable takeaway>
Promotion: none | CONVENTIONS.md | DECISIONS.md#ADR-nnn | TOOLS.md | VALIDATION.md
```

## Promotion rules

- Recurring pattern → `CONVENTIONS.md`
- Durable architectural choice → `DECISIONS.md` (ADR), cross-referenced here
- Safe or restricted command rule → `TOOLS.md`
- Completion or validation check → `VALIDATION.md`

After promotion, set the entry to `Status: promoted` and keep it as a breadcrumb; do not duplicate the rule body.

## Compaction

- Keep at most 40 active entries. When exceeded, consolidate related entries, promote what is durable, and mark the rest `superseded`.
- Compaction means summarizing and promoting, not erasing history. Record the compaction in `HANDOFF.md`.

## Entries

### L-001 — `contexto.md` is the only scope source

Date: 2026-10-19
Status: active
Confidence: observed
Scope: repo
Context: Adopting the context layer in an otherwise empty repository.
Evidence: the directory contains only `AGENTS.md`, `contexto.md`, and `.ai/`; no code, IaC, or manifests.
Pattern / rule: Read `contexto.md` before any implementation work and treat it as the draft PRD; do not invent scope or duplicate it into a second document.
Promotion: none

### L-002 — Local prerequisites are incomplete

Date: 2026-10-19
Status: active
Confidence: observed
Scope: local-kind
Context: Checking whether the kind-based lab can be validated.
Evidence: `kind` and `cilium` are not on `PATH`; `tofu` and `yq` are also missing, while Docker, kubectl, helm, terraform, and the AWS CLI are present.
Pattern / rule: Run `make up` only after installing `kind` and the Cilium CLI; record `helm` v4 chart-compatibility checks before pinning charts.
Promotion: TOOLS.md, VALIDATION.md

### L-003 — Tetragon on kind needs CRI and cgroup ID mapping

Date: 2026-10-19
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: Tetragon events had no pod or namespace association; `tetra getevents --namespace ebpf-lab` returned nothing.
Evidence: logs showed `FindCgroupID: found path without matching pod id`; after setting `tetragon.cri.enabled=true`, `cri.socketHostPath=/run/containerd/containerd.sock`, and `cgidmap.enabled=true`, events showed pod names and namespace filters worked.
Pattern / rule: On kind (and AL2023), enable CRI socket access and cgidmap in the Tetragon chart values; otherwise pod selectors and namespace filters silently match nothing.
Promotion: none

### L-004 — Slow first image pulls can leave Helm releases pending

Date: 2026-10-19
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: Installing Cilium on a cold kind cluster on a slow `quay.io` link.
Evidence: `helm -n kube-system list` showed `pending-install`; a later `helm upgrade` failed with "another operation in progress". The successful run uninstalled the release first. `local-up.sh` now reconciles `pending-*` before installing.
Pattern / rule: Expect tens of minutes for the first pull; never start a second install blindly. Clear pending releases instead.
Promotion: none

### L-005 — Hubble HTTP flows require an L7 policy

Date: 2026-10-19
Status: active
Confidence: observed
Scope: policies/cilium
Context: `hubble observe --protocol http` returned nothing for a working request path.
Evidence: the same traffic appeared as L3/L4 `policy-verdict` and `to-endpoint` flows; no HTTP layer was parsed.
Pattern / rule: Use L3/L4 filters for demos unless an explicit L7 policy or visibility annotation is in place.
Promotion: none

### L-006 — Tetragon matchArgs has no `In` operator

Date: 2026-10-19
Status: active
Confidence: observed
Scope: policies/tetragon
Context: Writing the SIGKILL enforcement policy.
Evidence: the CRD rejected `operator: In`; supported operators include `Equal`, `Prefix`, `Substring`, and others.
Pattern / rule: Model alternatives with multiple selectors using `Equal` (selectors are ORed) instead of an `In` list.
Promotion: none

### L-007 — Smoke tests must retry after a rollout

Date: 2026-10-19
Status: active
Confidence: observed
Scope: scripts/smoke-test.sh
Context: `make up` restarts deployments on every run to pick up `:dev` images.
Evidence: nginx returned 502 (`connect() failed: Connection refused`) for `/api/message` right after a rollout; the same request succeeded 10 seconds later.
Pattern / rule: Retry the end-to-end API check for a bounded window after a rollout instead of treating the first 502/504 as a product failure. Kubelet readiness does not guarantee Service endpoint propagation.
Promotion: none

### L-008 — Cilium selects pods, not containers

Date: 2026-10-20
Status: active
Confidence: observed
Scope: policies/cilium
Context: Building a pod with front, back, and api containers and trying to deny traffic between them.
Evidence: localhost traffic between containers returned `{"status":"ok"}`; policies only affected traffic entering the pod from outside. Denying 8081/8082 worked because ports map to containers.
Pattern / rule: L3/L4 policy cannot separate containers in the same pod. Expose each container on a distinct port when the demo needs a container-level deny, and state that intra-pod traffic bypasses Cilium.
Promotion: none

### L-009 — Tetragon enforcement applies to every container in a selected pod

Date: 2026-10-20
Status: active
Confidence: observed
Scope: policies/tetragon
Context: Applying one TracingPolicy to a three-container pod.
Evidence: shell exec was killed (exit 137) in `front`, `back`, and `api`; the policy has no container selector.
Pattern / rule: Use `podSelector` for pod-wide enforcement; a per-container rule would need a different mechanism.
Promotion: none

### L-010 — Reinstall Tetragon if events lose pod association

Date: 2026-10-20
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: After several Helm upgrades and a kind cluster recreation, Tetragon killed shells correctly but exported events with only the node name, so `tetra getevents --namespace` returned nothing.
Evidence: events showed `ebpf-lab-control-plane` instead of pod names; the CRI/cgidmap values were correct and a DaemonSet restart did not help. `helm uninstall tetragon` followed by a fresh install restored pod/container names.
Pattern / rule: When Tetragon events lack pod names, reinstall the release instead of only restarting pods. Verify with `tetra getevents --namespace ebpf-lab` before trusting the demo output.
Promotion: none

### L-011 — Loki needs a writable data directory

Date: 2026-10-20
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: Installing Loki chart 7.3.0 with persistence disabled.
Evidence: Loki crash-looped with `mkdir /var/loki: read-only file system`; enabling a 1 GiB PVC fixed it.
Pattern / rule: Keep `singleBinary.persistence.enabled=true` for this chart; disabling it leaves no writable `/var/loki`.
Promotion: none

### L-012 — kind local-path provisioner can lose API access after Cilium

Date: 2026-10-20
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: PVCs stayed Pending after Cilium replaced kube-proxy.
Evidence: local-path-provisioner logged `dial tcp 10.96.0.1:443: connect: no route to host`; restarting the provisioner pod restored API access and the PVC bound.
Pattern / rule: If PVCs never bind on kind with Cilium kube-proxy replacement, restart the `local-path-provisioner` deployment before disabling storage.
Promotion: none

### L-013 — Do not redefine `global` in the Prometheus chart config

Date: 2026-10-20
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: Adding scrape configs through `serverFiles.prometheus.yml`.
Evidence: Prometheus crash-looped with `field global already set in type config.plain`; the chart already renders `server.global`. Moving the scrape interval there and removing `global` from `serverFiles` fixed it.
Pattern / rule: Keep global settings under `server.global`; put only `scrape_configs` in `serverFiles.prometheus.yml`.
Promotion: none

### L-014 — Embedding an iframe in Grafana needs two settings

Date: 2026-10-20
Status: active
Confidence: observed
Scope: deployments/local-kind
Context: Embedding the Hubble UI in a Grafana text panel.
Evidence: the panel HTML is sanitized unless `panels.disable_sanitize_html=true`; the Hubble UI sends no `X-Frame-Options`/CSP headers, so it can be embedded. Both were verified in the rendered `grafana.ini`.
Pattern / rule: Set `security.allow_embedding=true` and `panels.disable_sanitize_html=true`; the iframe URL must be reachable from the browser (localhost port-forward), not from the Grafana pod.
Promotion: none
