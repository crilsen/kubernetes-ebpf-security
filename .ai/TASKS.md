# Current Work

## Active

- Validate the local target end to end (`make up`, scenarios, evidence) — current focus.

## Planned

1. ~~Confirm `contexto.md` as an approved PRD~~ — approved 2026-10-19.
2. ~~Initialize Git and publish the repository~~ — done (public, `crilsen/kubernetes-ebpf-security-lab`).
3. **Finish the local target first**: validate `make up` on a clean cluster, run the four scenarios, and record evidence.
4. Harden the local bootstrap from the real run: image-pull duration, port-forward lifecycle, failure messages, Helm timeout.
5. Keep the EKS target scaffolded but parked until the local target is validated end to end.
6. Revisit EKS: state backend, cost guard, disposable account, `make eks-up`, then destroy and record evidence.
7. Run the shared scenario matrix on both targets with documented adjustments.

## Blocked

- First-run image pulls from `quay.io` are very slow on the author network (tens of minutes); later runs are fast once cached.
- AWS account, region, credentials, and budget are not confirmed; the EKS target must not be applied yet.

## Completed

- 2026-10-19 — Adopted the context layer and populated `.ai/` from `contexto.md` and the observed environment.
- 2026-10-19 — Implemented the first full slice: Go API, nginx frontend, PostgreSQL, shared manifests, Cilium/Tetragon policies, kind/Helm/Kustomize local target, Terraform EKS scaffold, demo scripts, Makefile, and README.
- 2026-10-19 — Installed `kind` 0.33.0 and `cilium` 0.20.1; verified Terraform fmt/validate, shellcheck, Go tests, and Kustomize builds.
- 2026-10-19 — Validated the local target and all four scenarios; recorded evidence.
- 2026-10-19 — Initialized Git and pushed the public repository `crilsen/kubernetes-ebpf-security-lab`.
