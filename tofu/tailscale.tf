# The homelab tailnet's access policy and DNS settings. The OAuth client used here only has the
# policy-file and DNS scopes; the Tailscale operator in the cluster has its own client.
provider "tailscale" {
  oauth_client_id     = data.sops_file.secrets.data["tailscale_oauth_client_id"]
  oauth_client_secret = data.sops_file.secrets.data["tailscale_oauth_client_secret"]
}

resource "tailscale_acl" "this" {
  acl = file("${path.module}/tailscale-policy.hujson")
}

# MagicDNS gives every device a name under the tailnet's ts.net domain (needed for HTTPS
# certificates). The "HTTPS certificates" switch itself has no API and stays on in the console.
resource "tailscale_dns_preferences" "this" {
  magic_dns = true
}

# The tailnet always has a policy and DNS preferences, so they are imported rather than created;
# these blocks do nothing once the resources are in the state.
import {
  to = tailscale_acl.this
  id = "acl"
}

import {
  to = tailscale_dns_preferences.this
  id = "dns_preferences"
}
