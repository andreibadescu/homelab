#!/usr/bin/env bash
# restic against an app's backup repository, with the credentials from its encrypted Secret
# (kubernetes/apps/<app>/backup.sops.yaml). Works without the cluster:
# all it needs is this repository and the age key. See docs/backups.md.
set -euo pipefail
cd "$(dirname "$0")/.."
app=${1:?usage: make restic APP=<app> ARGS="<restic arguments>"}
shift
secret="kubernetes/apps/$app/backup.sops.yaml"
[ -f "$secret" ] || { echo "no backup secret for '$app' ($secret)" >&2; exit 1; }
for key in RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  export "$key=$(sops -d --extract "[\"stringData\"][\"$key\"]" "$secret")"
done
export RESTIC_CACHE_DIR=/tmp/restic-cache
exec restic "$@"
