# Cloudflare side of the public showcase (https://homelab.andreibadescu.com): a remotely managed
# tunnel with its routes, the DNS record pointing at it, a per-IP rate limit and the redirect of the
# bare address. The connector in the cluster (kubernetes/apps/cloudflared) reads the tunnel token
# from a Secret created here.
provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
}

data "cloudflare_zone" "andreibadescu" {
  filter = { name = "andreibadescu.com" }
}

locals {
  cf_account_id = data.cloudflare_zone.andreibadescu.account.id
  cf_zone_id    = data.cloudflare_zone.andreibadescu.id
  showcase_host = "homelab.andreibadescu.com"
  # Access token of the public dashboard: part of its public URL, not a secret. The publisher
  # sidecar in kubernetes/apps/showcase/grafana.yaml uses the same value.
  showcase_token   = "1dc30d40eb9e56906a89c0dfa85afe13"
  showcase_grafana = "http://grafana-public.showcase.svc:80"
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = local.cf_account_id
  name       = "homelab"
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = local.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

# Only the public dashboard, its API calls and Grafana's static files reach the cluster; every
# other path (login, API, Explore, other dashboards) gets a 404 from Cloudflare's edge.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = local.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  config = {
    ingress = [
      {
        hostname = local.showcase_host
        path     = "^/public-dashboards/${local.showcase_token}$"
        service  = local.showcase_grafana
      },
      {
        hostname = local.showcase_host
        path     = "^/api/public/dashboards/${local.showcase_token}(/.*)?$"
        service  = local.showcase_grafana
      },
      {
        hostname = local.showcase_host
        path     = "^/public/(build|fonts|img|plugins)/"
        service  = local.showcase_grafana
      },
      { service = "http_status:404" },
    ]
  }
}

resource "cloudflare_dns_record" "showcase" {
  zone_id = local.cf_zone_id
  name    = local.showcase_host
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Public showcase; managed by OpenTofu (github.com/andreibadescu/homelab)"
}

# The record was first created by hand with cloudflared; adopt it instead of creating a duplicate.
import {
  to = cloudflare_dns_record.showcase
  id = "0aa20de90b389292ec21cf9e0654d0b0/60cd03a5506e6b7e980e71bdca192986"
}

# Free plan: one rate-limit rule, 10-second window. A page load is about 50 requests, so 100 per
# 10 seconds per IP never affects visitors but stops floods before they reach the homelab.
resource "cloudflare_ruleset" "rate_limit" {
  zone_id = local.cf_zone_id
  name    = "homelab rate limit"
  kind    = "zone"
  phase   = "http_ratelimit"
  rules = [{
    description = "homelab showcase: at most 100 requests per 10 seconds per IP"
    expression  = "(http.host eq \"${local.showcase_host}\")"
    action      = "block"
    ratelimit = {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = 100
      mitigation_timeout  = 10
    }
  }]
}

resource "cloudflare_ruleset" "redirects" {
  zone_id = local.cf_zone_id
  name    = "homelab redirects"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"
  rules = [{
    description = "homelab showcase: the bare address opens the public dashboard"
    expression  = "(http.host eq \"${local.showcase_host}\" and http.request.uri.path eq \"/\")"
    action      = "redirect"
    action_parameters = {
      from_value = {
        status_code           = 302
        preserve_query_string = false
        target_url = {
          value = "https://${local.showcase_host}/public-dashboards/${local.showcase_token}"
        }
      }
    }
  }]
}

# The connector's namespace and tunnel token. Created here (not by Flux) because the token comes
# from Cloudflare; Flux deploys the connector itself into this namespace.
resource "kubernetes_namespace_v1" "cloudflared" {
  metadata {
    name = "cloudflared"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }

  depends_on = [talos_cluster.this]
}

resource "kubernetes_secret_v1" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace_v1.cloudflared.metadata[0].name
  }
  data = {
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  }
}
