#!/usr/bin/env bash
# Writes a kubeconfig for one of a project's accounts (docs/builds.md, docs/new-project.md):
#   ACCOUNT=builder (default): ~/.homelab/<tenant>-builder.kubeconfig, builds namespace only,
#     long-lived token from the Secret builder-token.
#   ACCOUNT=operator: ~/.homelab/<tenant>-operator.kubeconfig, exec/port-forward/restarts in the app
#     namespaces, token valid for 24 hours (run again for a new one).
# Runs in the toolbox with the admin kubeconfig.
set -euo pipefail
tenant=${1:?usage: make tenant-kubeconfig TENANT=<project> [ACCOUNT=builder|operator]}
account=${2:-builder}
admin=/root/.homelab/kubeconfig
case "$account" in
  builder)
    ns="$tenant-builds"
    token=$(kubectl --kubeconfig "$admin" -n "$ns" get secret builder-token -o jsonpath='{.data.token}' | base64 -d) ;;
  operator)
    ns="$tenant"
    token=$(kubectl --kubeconfig "$admin" -n "$ns" create token operator --duration=24h) ;;
  *) echo "unknown account '$account' (builder or operator)" >&2; exit 1 ;;
esac
out="/root/.homelab/$tenant-$account.kubeconfig"
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
  - name: $tenant-$account
    user: {token: "$token"}
contexts:
  - name: $tenant-$account
    context: {cluster: homelab, user: $tenant-$account, namespace: $ns}
current-context: $tenant-$account
KUBECONFIG
echo "wrote ~/.homelab/$tenant-$account.kubeconfig (namespace $ns)"
