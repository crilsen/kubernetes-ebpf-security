# Tools

The rules behind these lists live in `.ai/GUARDRAILS.md`.

## Local dependencies

Install or verify the host CLIs with `make deps` (Homebrew on macOS) or `make deps-check` to only report. The script never installs a runtime; Docker Desktop must be installed and started manually. `make up` runs the same check before touching the cluster.

## Current availability

Observed on the author machine on 2026-10-19:

| Tool | Version / path | Status |
| --- | --- | --- |
| git | 2.50.1 | present; repository initialized 2026-10-19 |
| docker | 29.7.2 | present and running |
| kind | v0.33.0 | installed 2026-10-19 |
| kubectl | v1.35.7 (Google Cloud SDK build) | present |
| helm | v4.3.0 | present; works with the Cilium/Tetragon charts |
| cilium CLI | v0.20.1 | installed 2026-10-19 |
| hubble CLI | 1.20.2 | installed 2026-10-19 |
| terraform | v1.16.1 | present; `fmt`/`validate` pass |
| tofu | — | not installed; Terraform was chosen (TDR-001) |
| aws CLI | 2.36.44 | present; credentials/profile not verified |
| jq / shellcheck / node / npm / python3 | present | — |
| yq | — | not required |

Authentication, AWS account, region, and state backend are **not verified**. Never store secrets in this file.

## Allowed without additional authorization

- Read and search repository files.
- Scoped, reversible, task-related edits.
- Run formatters, linters, syntax checks, and tests once they exist (`shellcheck`, `terraform fmt`, `terraform validate`, `helm lint`, `helm template`, app tests).
- Read-only commands and safe dry runs (`kubectl get/describe`, `kubectl apply --dry-run=client`).
- Local Docker image builds.
- Update this portable context.

## Requires explicit authorization

- `terraform apply` / `destroy`, `tofu apply` / `destroy`, or any IaC state mutation.
- `kubectl apply/delete` against a real cluster, `helm install/upgrade`, `kind create/delete` outside the documented `make` targets.
- **Creating or destroying AWS resources** — paid resources; always show account, region, environment name, cost estimate, and plan first.
- Secret or credential changes, committing secrets, destructive state operations.
- Any operation that exposes Hubble UI or the application beyond localhost.
- Installing system-wide tooling (e.g. `kind`, `cilium`, `tofu`) is an environment change: propose it before running.

## Technology-specific guidance

| Technology | Usually safe | Restricted |
| --- | --- | --- |
| Terraform/OpenTofu | `fmt`, `validate`, `plan` (with credentials) | `apply`, `destroy`, state edits |
| Kubernetes | `get`, `describe`, `diff`, client dry-run | real-cluster apply/delete |
| Helm | `lint`, `template` | install/upgrade against real environments |
| kind | `make up` / `make down` as documented | deleting clusters not created by this repo |
| Cilium/Tetragon | `cilium status`, `hubble observe`, `tetra getevents` (read-only) | changing CNI or policy state without approval |
| Static analysis | `tflint`, `checkov`, `trivy`, `shellcheck` | follow tool/project-specific impact rules |

## MCP servers and external tools

None configured for this project. Do not record endpoints, tokens, or credentials.

| Tool or MCP server | Purpose | Allowed | Restricted |
| --- | --- | --- | --- |
| — | — | — | — |
