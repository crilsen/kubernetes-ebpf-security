# Session Handoff

## Resume block (read first)

- Repo state: branch `main`, HEAD `6d3a6e7`, working tree clean, pushed to public `origin` (`github.com/crilsen/kubernetes-ebpf-security`)
- Source of truth: `AGENTS.md` → `.ai/`
- Budget / usage observed: unknown
- Checkpoint updated: 2026-10-19 23:00
- Last goal: rename the project to Kubernetes eBPF Security (repo/name only; descriptive text may still say lab)
- Annotation language: English (standing preference: no)
- Context maintenance: automatic
- Exact next action: attempt one cold-cache `make down && make up` run and record its duration and failures
- Blocked by: cold image pulls from `quay.io` are very slow on this network; the EKS target has no confirmed AWS account/budget
- Resume prompt: `Read AGENTS.md and .ai/HANDOFF.md. Continue from the Resume block. Do not rediscover context.`

## Goal

Deliver a working local lab first: kind + Cilium + Hubble + Tetragon + frontend → API → PostgreSQL, with reproducible bring-up, teardown, scenarios, and evidence.

## Current State

- Local target works: `make up` (warm cache) completes and the smoke test passes.
- All four scenarios ran successfully on the kind cluster and produced recorded evidence.
- The EKS target is scaffolded (Terraform, Helm values, scripts) and passes `terraform validate`; it has never been applied.
- No runtime executes on the host: everything runs in the kind cluster; only CLIs and port-forwards run locally.
- Repository is initialized with Git but not yet committed or pushed.

## What Was Done

- Implemented the Go API, nginx frontend, PostgreSQL manifests, Cilium baseline policies, and Tetragon observation/enforcement policies.
- Implemented the local kind target with Helm values, Kustomize overlays, `make up`, `make down`, smoke tests, and four demo scenarios.
- Implemented the AWS EKS Terraform scaffold, Cilium ENI values, IRSA role, cost/confirmation gates, and EKS smoke test.
- Validated locally: Cilium 1.20.3, Tetragon 1.7.1, Kubernetes 1.35.8.
- Fixed issues found by real runs: Tetragon CRI/`cgidmap`, `matchArgs` operator, macOS `timeout`, Hubble L7, pending Helm releases.
- Recorded evidence under `evidence/2026-10-19-local-baseline/`.
- `make up` now forwards and prints every local endpoint: web 8080, API 8082, Hubble UI 8081, Hubble Relay 4245.
- Added a live denied-path endpoint: the web pod calls `denied-target`, Cilium drops it, the browser gets 504, and Hubble shows `EGRESS DENIED`.

## Files Changed

- Application: `app/api/**`, `app/web/**`, `app/db/init.sql`
- Manifests/policies: `k8s/base/**`, `policies/cilium/baseline/**`, `policies/tetragon/**`
- Targets: `deployments/local-kind/**`, `deployments/aws-eks/**`
- Automation/docs: `scripts/**`, `demos/**`, `Makefile`, `README.md`, `.gitignore`, `.shellcheckrc`, `evidence/**`
- Context: `.ai/PROJECT.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `VALIDATION.md`, `TOOLS.md`, `TASKS.md`, `DECISIONS.md`, `REQUIREMENTS.md`, `LEARNINGS.md`, `HANDOFF.md`

## Decisions Made

- ADR-001 shared app/policies with per-target deployment directories.
- ADR-002 local target runs entirely inside kind/Docker; no host runtime.
- ADR-003 Cilium as primary CNI on EKS with ENI IPAM.
- TDR-001 Terraform; TDR-002 Go/nginx/PostgreSQL; TDR-003 pinned versions.
- PRD-001 (`contexto.md`) approved.

## Problems / Risks

- **Cold first run:** a single uninterrupted cold-cache `make up` is still unproven; pulls took ~30 minutes. Scripts now recover from `pending-*` Helm releases.
- **EKS unvalidated:** `terraform validate` passes, but no plan/apply ran; cost and IAM behavior are unproven.
- **EKS state:** local Terraform state by default; use a remote backend before shared use.
- **Demo credentials** are committed in the manifests by design; they are not secrets for real use.

## Validation Performed

- `make up` — completed; `make smoke` — PASS.
- `make demo-baseline`, `demo-microsegmentation`, `demo-observe`, `demo-enforce` — PASS.
- `make verify` — shellcheck, `go vet`/`go test`, Kustomize builds, `terraform fmt -check`, `terraform validate` — PASS.
- Evidence recorded in `evidence/2026-10-19-local-baseline/`.
- **Not validated:** cold-cache single run, EKS apply/destroy, scenario parity on EKS.

## Next Actions

1. Commit and push the initial repository as a public GitHub repo.
2. Run `make down && make up` from a cold cache and record the duration and any failures.
3. Decide whether to pre-pull/load images to make the first run deterministic.
4. When AWS budget is confirmed, apply the EKS target, run the same scenarios, record evidence, then destroy.
