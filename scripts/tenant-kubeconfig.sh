#!/usr/bin/env bash
# Writes ~/.homelab/<tenant>-builder.kubeconfig: the project's builder ServiceAccount token, valid only
# in <tenant>-builds (pods, jobs, volumes there; nothing else). Runs in the toolbox with the admin
# kubeconfig. See docs/builds.md.
set -euo pipefail
tenant=${1:?usage: make tenant-kubeconfig TENANT=<project>}
ns="$tenant-builds"
admin=/root/.homelab/kubeconfig
out="/root/.homelab/$tenant-builder.kubeconfig"
token=$(kubectl --kubeconfig "$admin" -n "$ns" get secret builder-token -o jsonpath='{.data.token}' | base64 -d)
server=$(kubectl --kubeconfig "$admin" config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')
ca=$(kubectl --kubeconfig "$admin" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
umask 077
cat > "$out" <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: homelab
    cluster: {server: "$server", certificate-authority-data: "$ca"}
users:
  - name: $tenant-builder
    user: {token: "$token"}
contexts:
  - name: $tenant-builds
    context: {cluster: homelab, user: $tenant-builder, namespace: $ns}
current-context: $tenant-builds
KUBECONFIG
echo "wrote ~/.homelab/$tenant-builder.kubeconfig (namespace $ns only)"
