# Builds

Images are built at home, inside the cluster, never on GitHub Actions. A build is a short-lived pod at
the lowest priority; nothing runs between builds. Images go to the registry (`docs/registry.md`).

## What each project gets

From its fence in `kubernetes/tenants/<project>/` (EnjoyDevOps: `enjoydevops-builds`):

| Piece | Details |
|---|---|
| Namespace `<project>-builds` | Pod Security `baseline` (Kaniko runs as root inside its own container, with no extra rights). Outgoing: DNS, the registry, the internet. Never the home network, the node or the Kubernetes API. |
| Push login | Secret `registry-push` (dockerconfigjson for `zot.registry.svc.cluster.local:5000`), valid only for `<project>/**`. Build pods mount it; the project's kubeconfig can't read it. |
| Build account (optional) | ServiceAccount `builder`: create and delete pods (including attach), read their logs, Jobs, volume claims, events. No Secrets, no exec, nothing outside its namespace.  EnjoyDevOps has none: its agent builds with the owner's admin kubeconfig (Andrei's decision, 2026-11-21). |
| Kubeconfig | `make tenant-kubeconfig TENANT=<project>` writes `~/.homelab/<project>-builder.kubeconfig` (works on the home network). |
| Quota | EnjoyDevOps: 4 CPUs and 6 GiB of memory limits, 30 GiB of volumes, 4 pods, 1 KVM device. PriorityClass `builds`: lowest, never evicts anything. |
| Scratch volumes | StorageClass `local-path-scratch`: on the data volume, deleted with their claim. Allowed only in build namespaces. |

## The builder

`registry.homelab.internal/platform/kaniko:v1.25.23`: Kaniko from Chainguard's maintained fork, built in the
cluster from the commit behind the version tag (`kubernetes/apps/platform-builds/kaniko.yaml`).

## Building an app image

Tested on 2026-11-20 with only the build account. From the project repository, on a clean, committed tree
(`git archive` sends exactly what is committed):

```bash
SHA=$(git rev-parse --short=12 HEAD)
Z=zot.registry.svc.cluster.local:5000
OVERRIDES=$(cat <<JSON
{"spec":{"priorityClassName":"builds","automountServiceAccountToken":false,"restartPolicy":"Never",
 "containers":[{"name":"kaniko","image":"registry.homelab.internal/platform/kaniko:v1.25.23",
  "stdin":true,"stdinOnce":true,
  "args":["--context=tar://stdin","--dockerfile=Containerfile","--target=edo",
          "--destination=$Z/enjoydevops/edo:$SHA","--insecure-registry=$Z",
          "--cache=true","--cache-repo=$Z/enjoydevops/cache","--digest-file=/dev/termination-log"],
  "resources":{"requests":{"cpu":"1","memory":"1Gi"},"limits":{"cpu":"4","memory":"4Gi"}},
  "volumeMounts":[{"name":"docker","mountPath":"/kaniko/.docker","readOnly":true}]}],
 "volumes":[{"name":"docker","secret":{"secretName":"registry-push",
  "items":[{"key":".dockerconfigjson","path":"config.json"}]}}]}}
JSON
)
git archive --format=tar HEAD | gzip | kubectl --kubeconfig ~/.homelab/kubeconfig \
  -n enjoydevops-builds run "build-edo-$SHA" --image=registry.homelab.internal/platform/kaniko:v1.25.23 \
  --restart=Never -i --overrides="$OVERRIDES"
```

Then wait until the pod's phase is `Succeeded`, read the digest from
`.status.containerStatuses[0].state.terminated.message`, delete the pod, and pin
`registry.homelab.internal/<project>/<image>@<digest>` in the manifests.

- **Two names for one registry.** Inside pods it is `zot.registry.svc.cluster.local:5000` (plain HTTP, no
  certificate); `registry.homelab.internal` only exists for the node's container runtime. The digest is the
  same under both.
- **Base images come straight from their registries** (Docker Hub, GHCR...). Kaniko's `--registry-map` and
  `--registry-mirror` towards Zot had no effect in testing, so don't use them.
- **Don't set `runAsNonRoot`** on Kaniko pods: Kaniko needs root inside its container.
- **One image per run;** several images from one Containerfile are several runs sharing the cache.

## Building lab VM images

A Job in `<project>-builds` that:

- requests the KVM device: `limits: {devices.kubevirt.io/kvm: "1"}` (tested: `/dev/kvm` usable as root);
- uses `priorityClassName: builds` and stays inside the quota;
- keeps its work directory on a claim with `storageClassName: local-path-scratch` (deleted with the claim);
- pushes with the `registry-push` Secret mounted as a Docker config file (`--dest-tls-verify=false` for Zot).

## Retention

The registry keeps the 2 most recently pushed tags of every image (current and previous). Build caches go
after 30 days without a pull. A rollback is a new build of the older commit.

## Platform images

Images under `platform/**` are built by Jobs in `platform-builds` (`kubernetes/apps/platform-builds`) with
the login `platform-builder`, which may push only there.
