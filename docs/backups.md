# Backups

Per app: each app with data worth keeping has its own restic repository in its own R2 bucket. Today
that is Ente.

## What is backed up

| App | What | Defined in |
|---|---|---|
| Ente | the database (`pg_dump`, custom format) and the object storage (photos and Locker files, already end-to-end encrypted by the apps) | `kubernetes/apps/ente/backup.yaml` |

Not backed up, because it is code in this repository and comes back with `make rebuild` and Flux: the
cluster, every app's configuration, the secrets, the OpenTofu state, and the Tailscale, Cloudflare,
GitHub and healthchecks.io settings. Not backed up because it is only recent history: metrics, logs
and traces.

## Where and when

- **One repository per app**, in the R2 bucket `<app>-backups` (EU jurisdiction, `tofu/backups.tf`).
  restic encrypts and deduplicates everything; each app's access key opens only its own bucket.
- **Nightly at 03:30** (Europe/Bucharest): the database dump first, then the files. Keeps 7 daily,
  4 weekly and 6 monthly snapshots, and runs `restic check` after every backup.
- **The restic password** and the access key are in `kubernetes/apps/<app>/backup.sops.yaml`
  (encrypted) and the password is also in the password manager. Without it the backups can't be read.
- Planned: a second copy on a USB drive attached to the node.

## Alerts and tests

- `EnteBackupMissing` (critical) fires after 30 hours without a successful backup; `KubeJobFailed`
  fires when a backup or restore-test job fails. Both reach ntfy.
- **Restore test**, monthly (the 1st, 05:00) and on demand:
  `kubectl -n ente create job restore-test-now --from=cronjob/ente-restore-test`. It restores the
  database into a throwaway PostgreSQL and compares row counts with the live one, and compares the
  restored files with the live storage by checksum.

## Looking at backups from the Mac

`make restic` runs restic in the toolbox with the app's credentials; it needs only this repository and
the age key, not the cluster:

```bash
make restic APP=ente ARGS="snapshots"
make restic APP=ente ARGS="restore latest --tag database --target /workspace/restore"  # into ./restore
```

## Restoring Ente

After a rebuild that lost the data volume, or to roll Ente back to a snapshot. With
`KUBECONFIG=~/.homelab/kubeconfig`:

1. Stop Flux from changing apps, and stop Ente's server and storage:
   ```bash
   flux suspend kustomization apps
   kubectl -n ente scale deploy/ente-museum statefulset/ente-s3 --replicas=0
   ```
2. Database (into `./restore`, then into PostgreSQL, replacing what is there):
   ```bash
   make restic APP=ente ARGS="restore latest --tag database --target /workspace/restore"
   kubectl -n ente exec -i ente-postgres-0 -- pg_restore -U pguser -d ente_db --clean --if-exists --no-owner < restore/work/ente_db.dump
   ```
3. Files (straight from R2 into the storage volume):
   ```bash
   kubectl apply -f docs/ente-restore-files.yaml
   kubectl -n ente wait --for=condition=complete job/ente-restore-files --timeout=1h
   kubectl -n ente delete job ente-restore-files
   ```
4. Start again: `flux resume kustomization apps` (Flux scales the server and storage back up), open
   the app, then delete `./restore`.

## Adding an app

1. Add its name to `backup_apps` in `tofu/backups.tf`, then `make apply`.
2. Create its access key (`docs/external-services.md`, "Backups") and store it with a new restic
   password in `kubernetes/apps/<app>/backup.sops.yaml`; save the password in the password manager.
3. Copy Ente's `backup.yaml` and `restore-test.yaml`, adapt what is dumped and copied, and give the
   job a network policy (its database and HTTPS to R2).
