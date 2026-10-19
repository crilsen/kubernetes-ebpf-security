# Evidence

One directory per validation run, named `YYYY-MM-DD-<target>-<scenario>`.

Each run records:

- **Versions:** kind, Kubernetes, Cilium, Hubble, Tetragon, Terraform/OpenTofu, CLI versions.
- **Command:** the exact command executed.
- **Expected result:** what should happen.
- **Observed result:** raw output or a trimmed excerpt plus an explanation.
- **Verdict:** passed, failed, or partially validated — never marked passed before execution.

Do not store cloud credentials, kubeconfigs, account IDs beyond what is necessary, or personal data in this directory.
