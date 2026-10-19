# Requirements

Product requirements describe what to build and why. PRDs are the source of truth for scope; agents treat them as requirements, not suggestions. Keep this file as a short index and store full PRDs under `docs/prd/`.

## Rules

- One PRD per feature or initiative, stored as `docs/prd/NNN-<slug>.md`.
- Status lifecycle: `Draft → Approved → Implemented → Superseded`.
- Only an **Approved** PRD drives implementation; use `.ai/workflows/feature.md`.
- Acceptance criteria must be concrete and testable, and validation maps back to them.
- Do not duplicate requirements here; link to the PRD.
- Record technical choices that a PRD depends on as ADR/TDR entries in `.ai/DECISIONS.md`.
- For large or risky work, a PRD can feed an optional spec-driven flow (`.ai/SPECS.md`, `docs/spec/`) that produces design, plan, and tasks before implementation.

## PRD format

```text
# PRD-NNN — Title
Status: Draft | Approved | Implemented | Superseded
Owner: <who>
Related decisions: ADR-NNN, TDR-NNN

Problem / Context:
...

Goals:
...

Non-goals:
...

Requirements:
- [ ] <requirement>

Acceptance criteria:
- [ ] <testable criterion>

Risks / Open questions:
...
```

## Index

| ID | Title | Status | Owner | File |
| --- | --- | --- | --- | --- |
| PRD-001 | Kubernetes eBPF Security Lab | Approved | repository owner | [`contexto.md`](../contexto.md) |

## Current requirements

### PRD-001 — Kubernetes eBPF Security Lab

- **Status:** Approved (confirmed by the owner on 2026-10-19).
- **Location:** `contexto.md` at the repository root, in Portuguese. This is the authoritative scope document until a `docs/prd/` copy exists.
- **Scope summary:** a single repository that demonstrates Cilium, Hubble, and Tetragon on two targets — local kind and AWS EKS — with a shared frontend → API → PostgreSQL application, shared Cilium/Tetragon policies, and shared demo scenarios.
- **Acceptance criteria:** see the "Critérios de aceite" section of `contexto.md` and the mapping in `.ai/VALIDATION.md`.
- **Open questions:** the architectural questions listed in `.ai/ARCHITECTURE.md`; they must become ADRs/TDRs before the affected work starts.
- **Note:** do not duplicate or translate the brief into a second source of truth; when a PRD is created under `docs/prd/`, link it here and mark this row accordingly.
