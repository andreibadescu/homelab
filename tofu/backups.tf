# Off-site backups: one R2 bucket per project, named <project>-backups. This one holds the homelab's
# restic repository (Ente's database and files); restic encrypts everything before upload. The
# bucket's access key (Object Read & Write on this bucket only) is created by hand in Cloudflare,
# because creating tokens needs a far more powerful permission than this token has.
resource "cloudflare_r2_bucket" "homelab_backups" {
  account_id = local.cf_account_id
  name       = "homelab-backups"
  # Data guaranteed to stay in the EU.
  jurisdiction = "eu"
  # Standard, not Infrequent Access: restic's pruning reads and deletes, which IA charges for.
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}
