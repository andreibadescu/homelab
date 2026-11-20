# New project

The checklist for hosting a project whose code and manifests live in its own repository, written from the
EnjoyDevOps setup (`kubernetes/tenants/enjoydevops/`). Copy that folder and adapt it; every step is code.

## In this repository

1. **Fence** (`kubernetes/tenants/<project>/`):
   - namespaces with Pod Security labels (`restricted` wherever possible);
   - ResourceQuota and LimitRange per namespace, including
     `local-path-scratch.storageclass.storage.k8s.io/persistentvolumeclaims: "0"` outside the builds namespace;
   - default deny plus DNS in each namespace;
   - RoleBindings of the ClusterRole `tenant-deployer` to `flux-<project>` in its app namespaces.
2. **Git access:** an Ed25519 deploy key. The private half and `known_hosts` (all three keys from
   `https://api.github.com/meta`) go in a SOPS Secret; the public half in `tofu/tenants.tf`
   (`github_repository_deploy_key`, `read_only = true`).
3. **Decryption key:** `age-keygen`, the private key as Secret `sops-age` (SOPS) in the project namespace; give
   the public key to the project for its `.sops.yaml`.
4. **Flux:** a GitRepository and a Kustomization in the project namespace (`serviceAccountName`, SOPS
   decryption), `suspend: true` until the project's secrets are encrypted for its key and its images exist.
   Add the namespace to the event sources in `kubernetes/infrastructure/monitoring/flux-alerts.yaml`.
5. **Builds:** namespace `<project>-builds` (label `homelab.andreibadescu.com/registry-push: "true"`), the
   builder account and token, a registry login limited to `<project>/**` (htpasswd entry in
   `zot-secret.sops.yaml` and an access-control entry in `zot.yaml`), its `registry-push` Secret
   (`docs/builds.md`).
6. **Backups:** the bucket `<project>-backups` in `tofu/backups.tf`, with no rule that could delete restic or
   point-in-time recovery data, and a bucket-limited access key created by hand (`docs/external-services.md`).
7. **Exceptions only when needed:** API access (`kubernetes/infrastructure/policies/baseline.yaml`), extra
   egress, privileged namespaces. Each one documented in the file that grants it.
8. **Public hostname:** the project's own Cloudflare tunnel, or a route on the homelab tunnel
   (`tofu/cloudflare.tf`).

## In the project's repository

- `deploy/k8s/`: namespace-scoped manifests only (no Namespaces, cluster-scoped objects or Flux objects),
  images pinned by digest from `registry.homelab.internal/<project>/...`, secrets as SOPS files.
- Network policies for its own pods, on top of the fence's default deny.
- Databases: CloudNativePG (`docs/databases.md`).
- Builds: `docs/builds.md`.

## Then

Resume the Flux Kustomization, watch it reconcile, and check the project's logs and metrics in Grafana.
