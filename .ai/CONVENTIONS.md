# Conventions

## Annotation language

- **English** for code comments and relay `.md` files (`AGENTS.md`, `.ai/`, `docs/`, `README.md`, PRD/spec/decision records). Recorded at adoption on 2026-10-19; the owner chose English while the original brief (`contexto.md`) is Portuguese.
- Ask again for each new task or session unless the owner declares it a standing preference.

## Observed conventions

No project code or configuration exists yet, so no historical naming, module, Kubernetes, Terraform/OpenTofu, scripting, CI/CD, or documentation conventions can be determined.

## Constraints from the implementation brief

- **Share, don't duplicate:** application manifests and policies live once and are reused by both targets. Only `deployments/local-kind/` and `deployments/aws-eks/` may hold target-specific files.
- **Explicit scope in policies:** every demo policy states what it constrains; use fictitious data only.
- **Fail loudly:** bootstrap steps must report diagnostics and identify the failing step instead of continuing.
- **Separate destructive behavior:** baseline bring-up is one path; blocking and enforcement scenarios are separate, explicit commands.
- **Do not claim unexecuted results:** evidence records the versions, command, expected result, and observed result, and no test is marked passed before it runs.
- **Local reachability only for Hubble UI**; never expose it publicly, including on EKS.

## Recommended conventions

- Lowercase, descriptive file and resource names; group by deployment target, not by parameter.
- Pin tool, chart, CNI, and cluster versions in one obvious place per target.
- Make targets are the public interface (`make up`, `make down`, `make eks-up`, `make eks-down`, plus scenario commands); scripts hold the implementation.
- Record meaningful architectural choices in `DECISIONS.md` before implementing them.

## Documentation

- Keep `AGENTS.md` short and route-oriented.
- Reference authoritative docs instead of copying them (see `.ai/PROJECT.md` and the brief for the Cilium/Tetragon/EKS links).
- Keep `TASKS.md` current-state only and `HANDOFF.md` operational, not a chat transcript.
- `LEARNINGS.md` is a bounded, append-only buffer; promote durable items into this file, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md`.
- Only the primary agent writes `HANDOFF.md`, `TASKS.md`, and `LEARNINGS.md`; subagents report back.
