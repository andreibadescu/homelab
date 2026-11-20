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

# Unfinished multipart uploads (an interrupted backup) are cleaned up after a day in every backup
# bucket. Only incomplete uploads are affected, never stored objects.
resource "cloudflare_r2_bucket_lifecycle" "backups" {
  for_each     = local.backup_apps
  account_id   = local.cf_account_id
  bucket_name  = cloudflare_r2_bucket.backups[each.key].name
  jurisdiction = "eu"
  rules = [{
    id                                 = "abort-unfinished-uploads"
    enabled                            = true
    conditions                         = { prefix = "" }
    abort_multipart_uploads_transition = { condition = { type = "Age", max_age = 86400 } }
  }]
}

# EnjoyDevOps's bucket existed before it was code (created by the EnjoyDevOps project). Its cluster
# backups live under restic/ (restic) and pitr/ (CloudNativePG, expired by its own retention), and must
# never be touched by a bucket rule: deleting old restic files would break every snapshot. Only the
# Mac's old age-encrypted dumps (edo/, kratos/) expire, after 30 days.
resource "cloudflare_r2_bucket" "enjoydevops_backups" {
  account_id = local.cf_account_id
  name       = "enjoydevops-backups"

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = cloudflare_r2_bucket.enjoydevops_backups
  id = "${local.cf_account_id}/enjoydevops-backups/default"
}

resource "cloudflare_r2_bucket_lifecycle" "enjoydevops_backups" {
  account_id  = local.cf_account_id
  bucket_name = cloudflare_r2_bucket.enjoydevops_backups.name
  # Cloudflare returns rules sorted by id; listing them the same way keeps plans clean.
  rules = concat(
    [{
      id                                 = "abort-unfinished-uploads"
      enabled                            = true
      conditions                         = { prefix = "" }
      abort_multipart_uploads_transition = { condition = { type = "Age", max_age = 86400 } }
    }],
    [for prefix in ["edo/", "kratos/"] : {
      id                        = "expire-${trimsuffix(prefix, "/")}-after-30-days"
      enabled                   = true
      conditions                = { prefix = prefix }
      delete_objects_transition = { condition = { type = "Age", max_age = 2592000 } }
    }]
  )
}
