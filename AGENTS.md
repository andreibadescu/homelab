# Working in this repository

For people and AI agents alike. The details are in [docs/workflow.md](docs/workflow.md).

- **Everything is code.** Infrastructure changes go through `tofu/` (OpenTofu) or `kubernetes/` (Flux).
  No manual changes in the cluster, Tailscale, Cloudflare, GitHub or healthchecks.io, except the
  one-time steps without an API in `docs/external-services.md`.
- **Workflow:** branch, `make check`, pull request, squash merge once CI passes. `tofu/` changes:
  `make plan` before merging, `make apply` after.
- **Commits:** author and committer `Andrei Badescu <andrei@andreibadescu.com>`, with no AI trailers
  ("Generated with", "Co-Authored-By"). Pass the identity per command
  (`git -c user.name=... -c user.email=...`) instead of changing git configuration. The same applies to
  pull request texts: no AI attribution.
- **Secrets:** never print, log or commit values. They live in `*.sops.yaml` files; `make check`
  rejects plaintext Secrets and runs gitleaks over the history.
- **Versions:** pin exact versions and only use releases at least 7 days old.
- **Destructive steps** (wiping volumes, deleting data, force-pushing, deleting repositories) need the
  owner's explicit OK first.

## Starting out

Read `README.md` (what runs and why), then `docs/workflow.md`, then the doc for the area you touch:

| Area | Doc | Code |
|---|---|---|
| Node, disk layout, rebuild, recovery passphrase | `docs/recovery.md`, `docs/bios-latitude-5550.md` | `tofu/talos.tf`, `Makefile` |
| Network rules (baseline, per namespace) | README "Security" | `kubernetes/infrastructure/policies/` |
| Registry (Zot) and the node's mirrors | `docs/registry.md` | `kubernetes/infrastructure/registry/`, `tofu/talos.tf` |
| Home builds (Kaniko, build namespaces) | `docs/builds.md` | `kubernetes/apps/platform-builds/`, `kubernetes/tenants/*/builds.yaml` |
| Databases (CloudNativePG) | `docs/databases.md` | `kubernetes/infrastructure/cnpg/` |
| Backups and restores | `docs/backups.md` | `tofu/backups.tf`, `kubernetes/apps/ente/` |
| Projects with their own repositories | `docs/new-project.md` | `kubernetes/tenants/` |
| Tailscale, Cloudflare, GitHub, healthchecks.io, manual steps | `docs/external-services.md` | `tofu/` |

**Access** (the owner's Mac; nothing secret is in the repository):

- Every tool runs in the toolbox image (`make toolbox`, then the make targets or `make shell`), on Docker
  via colima. Files mounted into it must live under `$HOME`: colima shares nothing else.
- Credentials: `~/.homelab/kubeconfig` and `~/.homelab/talosconfig` (`make creds` writes new ones); the age
  key in `~/Library/Application Support/sops/age/keys.txt` decrypts every `*.sops.yaml`, including
  OpenTofu's state key and API tokens in `tofu/secrets.sops.yaml`; OpenTofu reads GitHub through
  `GITHUB_TOKEN=$(gh auth token)`.
- The Kubernetes and Talos APIs are reachable only from the home network.

**Verify, don't assume:** after a change, `flux get kustomizations -A` is all Ready and `make plan` shows
no changes; test the behaviour itself (a throwaway pod for network rules, `kubectl auth can-i` for
permissions) and delete what the test created.

**Known pitfalls:**

- After `make apply`, commit the updated `tofu/terraform.tfstate` in a pull request.
- `kubectl auth can-i create pods/exec` asks about a pod named "exec"; use `--subresource=exec`.
- Jobs are immutable: Flux recreates them only with the `kustomize.toolkit.fluxcd.io/force` annotation,
  and a version in the Job name makes a new build run once.
- An R2 bucket must be empty before it can be deleted: empty it with a lifecycle rule first.

## Projects and their agents

Projects with their own repositories (today EnjoyDevOps) are fenced in `kubernetes/tenants/<project>/`.
Their manifests, images, database, backup jobs, restores and cutovers belong to the project's repository
and its own agent; the homelab agent changes only this repository and the platform. A project agent gets a
narrow kubeconfig from `make tenant-kubeconfig TENANT=<project>` (its builds namespace). For one-off work
in its app namespaces (a restore, a cutover), add an operator account like the one EnjoyDevOps had for its
cutover (git history of `kubernetes/tenants/enjoydevops/operator.yaml`, removed afterwards) and use
`ACCOUNT=operator` (24-hour token).

Coordination with the EnjoyDevOps agent happens through files in the owner's private notes folder
`~/p/homelab-notes/` (outside this repository): `homelab-to-enjoydevops.md` holds messages from the
homelab agent (newest last), `enjoydevops-answers.md` its replies. The owner tells each agent when a new
message is there.

## Open work

The GitHub issues of this repository (the Renovate dependency dashboard aside).
