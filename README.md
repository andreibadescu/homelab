# homelab

[![ci](https://github.com/andreibadescu/homelab/actions/workflows/ci.yaml/badge.svg)](https://github.com/andreibadescu/homelab/actions/workflows/ci.yaml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](https://github.com/renovatebot/renovate)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A single-node Kubernetes cluster on a Dell Latitude 5550, running Talos Linux and managed entirely as
code from this repository: OpenTofu builds and bootstraps the node, Flux deploys everything else from
Git. Nothing is exposed to the internet; apps are reached over Tailscale.

```mermaid
flowchart LR
  dev[Mac: make plan / apply<br/>toolbox container] -->|OpenTofu| talos[Talos node<br/>Secure Boot, TPM-encrypted disks]
  git[(GitHub repo)] -->|Flux, every minute| k8s
  talos --> k8s[Kubernetes + Cilium]
  k8s --> apps[Ente, monitoring,<br/>website checks]
  apps -->|Tailscale operator| tailnet[Homelab tailnet<br/>shared per device]
  apps -->|alerts| ntfy[ntfy / healthchecks.io]
  renovate[Renovate] -->|pull requests| git
  ci[GitHub Actions: make check] -->|on every PR| git
```

## What runs

| Layer | Component | Defined in |
|---|---|---|
| OS | Talos Linux (Secure Boot, TPM-encrypted disks) | `tofu/` |
| Network | Cilium (replaces Flannel and kube-proxy, enforces NetworkPolicy), Hubble Relay | `tofu/talos.tf` |
| GitOps | Flux: syncs `kubernetes/clusters/homelab` from GitHub every minute | `tofu/flux.tf` |
| Storage | local-path volumes on the encrypted `data` volume (`/var/mnt/data`) | `kubernetes/infrastructure/local-path` |
| Private access | Tailscale operator: apps get HTTPS names on the homelab tailnet (`*.junco-ulmer.ts.net`) | `kubernetes/infrastructure/tailscale` |
| Metrics | metrics-server (kubelet certificates verified) | `kubernetes/infrastructure/metrics-server`, `kubelet-cert-approver` |
| Monitoring | Prometheus, Alertmanager (alerts to ntfy), Grafana | `kubernetes/infrastructure/monitoring` |
| Apps | Ente Photos and Locker (end-to-end encrypted), default-deny network policies | `kubernetes/apps/ente` |
| Website checks | enjoydevops.io and andreibadescu.com probed every minute (blackbox exporter) | `kubernetes/apps/website-monitoring` |

The homelab tailnet holds only the cluster's devices. People reach an app through Tailscale
**device sharing**: they see the shared app and nothing else.

## Repository layout

| Path | What |
|---|---|
| `tofu/` | OpenTofu: Talos image, machine config, install and bootstrap, Cilium, Flux bootstrap. State is encrypted and committed. |
| `kubernetes/clusters/homelab/` | Flux entry point: Flux itself, then the `infrastructure` and `apps` stages |
| `kubernetes/infrastructure/` | Platform components (one folder each) |
| `kubernetes/apps/` | Applications (one folder each) |
| `.devcontainer/` | The toolbox image every command runs in |
| `scripts/check.sh` | All repository checks (`make check`, also run by CI) |
| `docs/` | BIOS checklist, recovery runbook, external services (Tailscale, alerts, Renovate) |
| `renovate.json` | Automatic version updates |
| `credential-expiry.yaml` | When the admin credentials expire (checked monthly by a GitHub workflow) |

## How changes flow

- **Node and cluster** (Talos, Kubernetes, Cilium, Flux itself): edit `tofu/`, run `make plan` and
  `make apply`. Cilium changes also need `make sync-manifests`, because Talos only installs its
  built-in manifests when a cluster is created.
- **Everything in Kubernetes**: edit `kubernetes/` and push. Flux applies it within a minute.
- **Versions**: everything tracks the newest stable release. [Renovate](renovate.json) opens pull
  requests; Talos, Kubernetes and Flux bumps update OpenTofu and the toolbox together.

## CI/CD

- **CI** ([.github/workflows/ci.yaml](.github/workflows/ci.yaml)) runs `make check` on every pull
  request and push, inside the toolbox: OpenTofu format and validation, every Kubernetes manifest
  rendered and validated against schemas (including CRDs), a check that every Secret is
  SOPS-encrypted, yamllint, shellcheck, actionlint, gitleaks over the whole history, and Renovate's
  config validator.
- **CD for Kubernetes** is Flux: a merge to `main` is live within a minute, and a failed
  reconciliation alerts the phone.
- **CD for the node** (`tofu/`) is deliberately manual: `make plan` and `make apply` from the admin
  Mac. GitHub can't reach the home network and never holds the age key.

## Toolbox and commands

Every command runs in a container built from [.devcontainer/Dockerfile](.devcontainer/Dockerfile)
(OpenTofu, talosctl, kubectl, Helm, Flux, sops, age). Downloads are checksum-verified; `age` comes
from Debian's signed packages. The host needs only **Docker** (for example Colima) and **make**.
The toolbox mounts the repo, `~/.homelab` (admin credentials) and the age key (read-only), and also
works as a VS Code / Windsurf Dev Container.

| Command | What |
|---|---|
| `make shell` | Shell inside the toolbox |
| `make plan` / `make apply` / `make output` | OpenTofu (`make init` first on a fresh clone) |
| `make rebuild` | Install and bootstrap a node in maintenance mode again, keeping the cluster's secrets ([docs/recovery.md](docs/recovery.md)) |
| `make creds` | Write `~/.homelab/talosconfig` and `~/.homelab/kubeconfig`, and record their expiry |
| `make sync-manifests` | Push Talos's built-in manifests (Cilium, CoreDNS) to the cluster: dry run first, then asks |
| `make check-talos-config` | Validate the rendered machine config with `talosctl validate` |
| `make check` | Every repository check, exactly as CI runs them |
| `make fmt` / `make validate` | Format and validate the OpenTofu code |
| `make upgrade`, then `make lock` | Move providers to new versions and record hashes for all platforms |

The Makefile passes your `gh auth token` to OpenTofu through the environment (for Flux's deploy key
on GitHub). It is never written to disk.

## Day to day

- `homelab` (a shell alias for `export KUBECONFIG=~/.homelab/kubeconfig`), then `kubectl`,
  `kubectl radar` or `sofka`. These work on the home network.
- Reaching the apps (`*.junco-ulmer.ts.net`) needs the device shared to your Tailscale account and
  its name resolved. Phones use Tailscale DNS by default. On a Mac with **Use Tailscale DNS** off,
  send only `ts.net` names to Tailscale's resolver and leave all other DNS unchanged:
  `sudo mkdir -p /etc/resolver && echo "nameserver 100.100.100.100" | sudo tee /etc/resolver/ts.net`
  (undo: `sudo rm /etc/resolver/ts.net`).
- The admin credentials are valid for a year. A GitHub workflow opens an issue 45 days before they
  expire; renew with `make creds` and commit `credential-expiry.yaml`.

## Ente accounts

- Registration is closed (`internal.disable-registration` in `kubernetes/apps/ente/config/museum.yaml`).
  To add someone: set it to `false`, push, let them sign up, then set it back to `true`.
- The server sends no email: sign-up verification codes appear in museum's log
  (`kubectl -n ente logs deploy/ente-museum | grep -i "verification code"`).
- New accounts get 10 GB. Raise it to 100 TB (what Ente's admin tool calls "no limit"):
  `kubectl -n ente exec ente-postgres-0 -- psql -U pguser -d ente_db -c "update subscriptions set storage = 109951162777600 where product_id = 'free';"`
- Apps: on the first screen tap the logo 7 times and set the server to
  `https://ente-api.junco-ulmer.ts.net`. The web apps on this server already use it.

## Monitoring and alerts

- **Grafana**: `https://grafana.junco-ulmer.ts.net` (share the `grafana` device to your account in the
  homelab tailnet). User `admin`; the password is in
  `kubernetes/infrastructure/monitoring/grafana-admin.sops.yaml` (the file's first lines show the
  command). Grafana keeps no state: its dashboards and data source come from the chart.
- **Prometheus** scrapes the API server, kubelets and containers, the node (node-exporter), Kubernetes
  objects and CoreDNS every 60 s and keeps 15 days (at most 8 GB) on the data volume.
- **Alerts**: warning and critical alerts go to a private **ntfy** topic. Install the ntfy app and
  subscribe to the topic in `kubernetes/infrastructure/monitoring/alertmanager-notify.sops.yaml` (it
  works like a password, so keep it private). Informational alerts stay in Grafana and Alertmanager.
  Flux reports failed reconciliations to Alertmanager too.
- **Websites**: enjoydevops.io (app and sign-in health endpoints) and andreibadescu.com are checked
  every minute from the homelab. `WebsiteDown` (critical) fires after 5 minutes of failures and
  `WebsiteCertificateExpiresSoon` (warning) 14 days before a certificate expires.
- **Dead man's switch**: the always-firing `Watchdog` alert pings healthchecks.io (check `homelab`)
  about every minute. If the pings stop for about 15 minutes (server, network or Alertmanager down),
  healthchecks.io notifies the same ntfy topic. The ping URL is in the same SOPS file.

## Secrets

- Secrets are committed only as `*.sops.yaml`, encrypted with **age** ([.sops.yaml](.sops.yaml)):
  - `tofu/secrets.sops.yaml`: the OpenTofu state key, the data-volume recovery passphrase and Flux's
    age key. Encrypted to your key only.
  - `kubernetes/**/*.sops.yaml`: Kubernetes Secrets, encrypted to your key **and** the cluster's key,
    so Flux can decrypt them in the cluster.
- OpenTofu **state and plans are encrypted** (AES-GCM, enforced) with the state key, through
  `tofu/state-key.sh`.
- Your age private key lives at `~/Library/Application Support/sops/age/keys.txt` and **must be in
  your password manager**. Without it, nothing in this repository can be decrypted.

## Security

- **Boot and disks**: Secure Boot with the Sidero keys (only Sidero-signed Talos boots), and
  TPM-sealed LUKS2 on STATE, EPHEMERAL and the data volume, plus a recovery passphrase on the data
  volume. The disks can't be read on other hardware without that passphrase.
- **Admin access**: the Talos API (50000) and the Kubernetes API (6443) are reachable on the home
  network and require the client certificates in `~/.homelab`.
- **Apps**: reachable only through Tailscale, never from the internet. Ente's namespace denies all
  traffic except the paths it needs (Cilium enforces it).
- **No inbound ports** are opened on the router. Public apps will leave through outbound-only
  Cloudflare Tunnels.

## Adapting this to your own hardware

1. `tofu/variables.tf`: cluster name, node IP, install disk, Talos extensions.
2. `.sops.yaml`: your own age keys (yours and a new cluster key), then re-create every
   `*.sops.yaml` and delete `tofu/terraform.tfstate` (it belongs to this cluster).
3. Replace `junco-ulmer.ts.net` in `kubernetes/` with your tailnet's name, and set up the external
   services in [docs/external-services.md](docs/external-services.md).
4. Follow the BIOS checklist for your machine and the bootstrap below.

## Bootstrap and recovery

First install: [docs/bios-latitude-5550.md](docs/bios-latitude-5550.md), then boot the Secure Boot
ISO (`make output` → `iso_secureboot_url`) in maintenance mode, `make plan`, `make apply` (this wipes
the install disk), `make creds`.

Rebuilds, disk layout changes, BIOS updates and reading the data volume elsewhere:
[docs/recovery.md](docs/recovery.md).
