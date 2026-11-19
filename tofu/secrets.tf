data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  data_recovery_passphrase = data.sops_file.secrets.data["data_recovery_passphrase"]
}
