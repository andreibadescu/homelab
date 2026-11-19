# The dead man's switch on healthchecks.io: the check that Alertmanager's always-firing Watchdog alert
# pings about every minute. If the pings stop, healthchecks.io alerts through ntfy (the phone) and by
# email (a second, independent channel). Integrations have no API (created once in the web UI,
# docs/external-services.md); the check's ping URL stays in
# kubernetes/infrastructure/monitoring/alertmanager-notify.sops.yaml.
#
# The check was adopted once with `tofu import healthchecksio_check.homelab <uuid>`, the UUID being
# the last part of the ping URL. It is deliberately not written here: it works like a password.
provider "healthchecksio" {
  api_key = data.sops_file.secrets.data["healthchecks_api_key"]
}

data "healthchecksio_channel" "ntfy" {
  kind = "ntfy"
}

data "healthchecksio_channel" "email" {
  kind = "email"
}

resource "healthchecksio_check" "homelab" {
  name     = "homelab"
  desc     = "Alertmanager's Watchdog alert pings this about every minute. Silence means the homelab, its network or Alertmanager is down."
  tags     = ["homelab"]
  timeout  = 300 # expected ping interval: 5 minutes
  grace    = 600 # then 10 more minutes before alerting
  channels = [data.healthchecksio_channel.ntfy.id, data.healthchecksio_channel.email.id]
}
