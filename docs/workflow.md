# Workflow

Everything is code: OpenTofu in `tofu/`, Flux in `kubernetes/`. Changes are made in files, reviewed in
a pull request and applied from `main`; nothing is changed by hand in the cluster, Tailscale,
Cloudflare, GitHub or healthchecks.io. The only manual steps are the ones no API covers, listed in
[external-services.md](external-services.md).

## A change, step by step

1. Branch from `main`: `git switch -c <topic>`.
2. Change files, then run `make check`: the same checks as CI (OpenTofu, Kubernetes schemas, encrypted
   secrets, lint, gitleaks), inside the toolbox. `make hooks` (once per clone) runs it automatically
   before every push.
3. Commit as `Andrei Badescu <andrei@andreibadescu.com>`, without AI trailers.
4. Push the branch and open a pull request: `gh pr create --fill`, then
   `gh pr merge --auto --squash`. It merges itself when CI passes, as one commit titled like the pull
   request.
5. After the merge:
   - `kubernetes/`: Flux applies `main` within a minute (`flux reconcile` to hurry it).
   - `tofu/`: run `make plan` from an up-to-date `main` and `make apply` (attach the plan summary to
     the pull request before merging).

## Rules

- `main` accepts changes only through pull requests with a passing `check` job (`tofu/github.tf`).
  The owner can still push directly when GitHub or CI is down; follow up with a pull request.
- CI runs on pull requests and on `main`. It is a final check, not the place to find out whether
  something works: that is `make check` and testing locally.
- Renovate's pull requests merge themselves when small (patch and digest updates of charts, images
  and actions). Talos, Kubernetes, Cilium and Flux updates wait for a person, since they need
  `make apply`.
- New dependency versions must be at least 7 days old.
- Anything destructive (wiping volumes, deleting data, force-pushing) needs the owner's explicit OK.
