# Registry

[Zot](https://zotregistry.dev) runs in the cluster (`kubernetes/infrastructure/registry`) and does two jobs:

1. **Private images built at home.** Projects push their images to it; their manifests reference them as
   `registry.homelab.internal/<project>/<image>@sha256:...`. That name exists only on this node.
2. **A cache of public registries.** docker.io, ghcr.io, quay.io and registry.k8s.io are fetched once and
   then served locally (stored under `docker.io/...`, `ghcr.io/...` and so on).

## How the node uses it

The node's container runtime is pointed at Zot's fixed internal address `10.96.0.50:5000` by Talos
`RegistryMirrorConfig` documents (`tofu/talos.tf`):

- `registry.homelab.internal`: Zot only, no fallback.
- The four public registries: through Zot, **falling back to the internet** when Zot is unavailable, so
  the cluster never depends on it (Zot's own image included).

The address is a ClusterIP: reachable from the node, not from the LAN or the internet.

## Access

- **Pulling** needs no login. Only the node and namespaces labelled
  `homelab.andreibadescu.com/registry-push: "true"` (build namespaces) can connect at all.
- **Pushing** needs a login. Logins are bcrypt entries in `kubernetes/infrastructure/registry/zot-secret.sops.yaml`:
  `homelab-admin` (password `registry_admin_password` in `tofu/secrets.sops.yaml`), and one user per
  project limited to its own prefix, added with the project's fence.

## Storage and retention

- 50 Gi on the data volume. Every layer is stored once (dedupe); garbage collection runs daily.
- Project images keep their **2 most recently pushed tags** (current and previous, for rollback). The
  count is by pushes, so an image that hasn't changed for a long time is never removed.
- Cached public images and build caches stay while they are pulled at least once in 30 days.
- No backup: everything in it can be rebuilt (`make images` in the project) or downloaded again.

## Checking it

```bash
kubectl -n registry port-forward svc/zot 5000:5000 &
curl -s http://localhost:5000/v2/_catalog          # repositories
curl -s http://localhost:5000/v2/<repo>/tags/list  # tags of one repository
```
