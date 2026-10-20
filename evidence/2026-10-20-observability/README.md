# Run 2026-10-20 — runtime dashboard

## Environment

Same kind cluster as the earlier runs. See [`versions.txt`](versions.txt):

| Component | Version |
| --- | --- |
| Grafana | 12.3.1 (chart 10.5.15) |
| Loki | 3.6.11 (chart 7.3.0) |
| Promtail | 3.5.1 (chart 6.17.1) |
| Tetragon | 1.7.1 |

## Data flow

```text
Tetragon (per node) → /var/run/cilium/tetragon/tetragon.log
                           │  hostPath
                           ▼
                    Promtail (DaemonSet) → Loki (single binary, 1 GiB)
                                                 │
                                                 ▼
                                      Grafana (Loki datasource)
```

## Command and results

Command: `make obs-check` (see [`obs-check.log`](obs-check.log)).

| Check | Expected | Observed |
| --- | --- | --- |
| Grafana health | `database: ok` | `{"database":"ok","version":"12.3.1"}` |
| Provisioned dashboard | “Tetragon runtime events” present | Found in folder `Tetragon` |
| Tetragon events in Loki | At least one `process_exec` | 5 events returned |

A manual query with `{job="tetragon"} |= "\"namespace\":\"ebpf-lab\""` returned real `process_exec` records with pod and container names, confirming the full path from the eBPF event to the dashboard.

## Issues found while building this

1. **Loki requires a writable data directory.** With persistence disabled, `/var/loki` is read-only and Loki crash-loops. The chart now uses a 1 GiB PVC.
2. **The kind local-path provisioner lost API access after Cilium replaced kube-proxy.** Its reflector logged `dial tcp 10.96.0.1:443: connect: no route to host`, so PVCs stayed pending. Restarting the provisioner pod restored it and the PVC bound.
3. **Tetragon pod association was broken before this run.** A fresh Tetragon install was required; see L-010 in `.ai/LEARNINGS.md`.

## Scope notes

- Grafana is exposed only through a localhost port-forward (`127.0.0.1:3001`).
- Loki data is ephemeral and retained for 24h; this is a demo dashboard, not a logging backend.
- Sigkill enforcement events are not exported by Tetragon in this setup; the demos validate them through exit code 137.
