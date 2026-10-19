# Validation

## Completion rule

Before completion, run all applicable project validations that are available and safe. Report each as **Validated**, **Partially validated**, or **Not validated**, with the reason for anything not run. Never claim validation that did not occur, and never mark a demo scenario as passed before it was executed on a real cluster.

## Annotation language

1. Confirm the annotation language was asked and recorded in `.ai/HANDOFF.md` (currently English, chosen at adoption).
2. Verify code comments and relay `.md` files use the confirmed language.

## Available now

Nothing implementable exists yet. Current applicable checks:

- `git` is not initialized in this directory; repository history cannot be validated until `git init` (owner decision).
- The context files can only be reviewed for consistency, not executed.

## Terraform / OpenTofu (once `deployments/aws-eks/tofu` exists)

1. `terraform fmt -recursive` or `tofu fmt`.
2. `terraform validate` or `tofu validate`.
3. `tflint` when configured.
4. `terraform plan` / `tofu plan` only with credentials, backend, and permission; always show the plan before any apply.

## Kubernetes / Helm (once manifests exist)

1. Validate YAML (`kubectl apply --dry-run=client -f ...` or a configured linter).
2. `helm lint` and `helm template` for charts.
3. `cilium connectivity test` on the local cluster after install, when the CLI is available.
4. No real-cluster mutation without explicit authorization.

## Scripts and applications

1. `shellcheck` for shell scripts.
2. Formatters, linters, and tests for the frontend and API once they exist.
3. `docker build` of the project images when the Dockerfile exists.

## Acceptance validation (from `contexto.md`)

Each item must be demonstrated with recorded evidence under `evidence/`:

| Criterion | How it is validated | Status |
| --- | --- | --- |
| README explains architecture and local/EKS differences | Manual review against `ARCHITECTURE.md` | Validated (README + `docs`-free architecture section) |
| `make up` reproduces the local lab and validates the app | Fresh run from a clean machine; capture output | Partially validated — completed after cached pulls; a single cold-cache run was interrupted by the agent timeout (see `evidence/2026-10-19-local-baseline/`) |
| EKS deployment uses IaC with create/validate/destroy commands | `make eks-up`, validation run, `make eks-down` | Not validated (configuration validates; never applied) |
| Same functional scenarios run on both targets | Run scenario matrix locally and on EKS; document adjustments | Not validated (local only) |
| Evidence includes versions, commands, expected and observed results | Inspect `evidence/` | Validated (`evidence/2026-10-19-local-baseline/`) |
| No test marked passed before execution | Review evidence timestamps and outputs | Validated |
| Cluster Mesh, second provider, production remain out of scope | Review scope and README | Validated |

## Last executed checks (2026-10-19)

- `make up` — completed; `make smoke` — PASS.
- `make demo-baseline`, `demo-microsegmentation`, `demo-observe`, `demo-enforce` — PASS.
- `make verify` — shellcheck, `go vet`/`go test`, Kustomize builds, `terraform fmt -check`, `terraform validate` — PASS.
- `terraform validate` uses downloaded modules; no AWS credentials were used and no plan/apply ran.

## Environment facts affecting validation

- Available: `git`, `docker` 29.7.2, `kubectl` v1.35.7, `helm` v4.3.0, `terraform` v1.16.1, `aws` 2.36.44, `jq`, `shellcheck`, `node`, `npm`, `python3`.
- Missing: `kind`, `cilium` CLI, `tofu`, `yq` — install before local or EKS validation.
