# Databases (CloudNativePG)

Projects run PostgreSQL with [CloudNativePG](https://cloudnative-pg.io), installed by the platform
(`kubernetes/infrastructure/cnpg`, namespace `cnpg-system`):

- **Operator** v1.30.1: runs each project's PostgreSQL `Cluster` in the project's namespace.
- **Barman Cloud plugin** v0.16.0: continuous WAL archiving and base backups to object storage (R2), so a
  database can be restored to any second. Its link to the operator uses certificates from **cert-manager**
  (`kubernetes/infrastructure/cert-manager`).

## What a project defines (in its own repository)

A `Cluster`, an `ObjectStore` (bucket prefix and credentials) and a `ScheduledBackup`, plus network
policies for its database pods:

- ingress from namespace `cnpg-system` on ports 8000 (status) and 5432;
- egress to the Kubernetes API (`toEntities: [kube-apiserver]`) and HTTPS to the object storage.

The project's Flux account may manage `postgresql.cnpg.io` and `barmancloud.cnpg.io` objects in its own
namespaces (`kubernetes/tenants/<project>/rbac.yaml`).

## Safeguards

- **API access only for real database pods.** The cluster-wide rule blocks the Kubernetes API for app pods
  (`kubernetes/infrastructure/policies/baseline.yaml`). Pods labelled `cnpg.io/cluster` are exempt, and an
  admission policy lets only the CloudNativePG operator set that label (`cnpg-cluster-label.yaml`).
- **No unattended restarts.** Renovate never merges updates of the operator, the plugin or cert-manager by
  itself, and the operator replaces its manager inside running database pods instead of restarting
  PostgreSQL (`ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES`).
- **Backups are never expired by bucket rules.** Each project's bucket rules are code (`tofu/backups.tf`);
  the point-in-time archive (`pitr/`) is expired only by CloudNativePG's own retention policy.
