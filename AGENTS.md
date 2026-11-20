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
