# Off-site backups: one R2 bucket per app, named <app>-backups. Each app also gets its own access key
# (created by hand in Cloudflare: Object Read & Write on its bucket only) and its own restic password,
# so one app can never read or delete another app's backups. The platform itself needs no backup:
# everything that defines it is in this repository.
#
# Adding an app: add its name here, `make apply`, then create its access key
# (docs/external-services.md, "Backups").
locals {
  backup_apps = toset(["ente"])
}

resource "cloudflare_r2_bucket" "backups" {
  for_each   = local.backup_apps
  account_id = local.cf_account_id
  name       = "${each.key}-backups"
  # Data guaranteed to stay in the EU.
  jurisdiction = "eu"
  # Standard, not Infrequent Access: restic's pruning reads and deletes, which IA charges for.
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}
