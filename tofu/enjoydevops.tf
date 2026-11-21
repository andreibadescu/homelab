# enjoydevops.io, the EnjoyDevOps site: DNS (tunnel, mail, Brevo) and the edge rules that protect sign-up.
# Adopted from the zone as it was configured by hand and by EnjoyDevOps's scripts/cloudflare-setup.py; the
# import blocks only take effect once. Email Routing (forwarding addresses) is not here yet: the OpenTofu token
# has no Email Routing permission.

data "cloudflare_zone" "enjoydevops" {
  filter = { name = "enjoydevops.io" }
}

resource "cloudflare_dns_record" "edo_cname_apex" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "enjoydevops.io"
  type    = "CNAME"
  content = "a4eaa5fd-5853-4bb7-b30c-b6c78f24ad4b.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "enjoydevops tunnel"
}

import {
  to = cloudflare_dns_record.edo_cname_apex
  id = "c884632e448ebc555c4c947a3b80b30c/e611bd4c903509b35791f688e1002e9b"
}

resource "cloudflare_dns_record" "edo_cname_app" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "app.enjoydevops.io"
  type    = "CNAME"
  content = "a4eaa5fd-5853-4bb7-b30c-b6c78f24ad4b.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

import {
  to = cloudflare_dns_record.edo_cname_app
  id = "c884632e448ebc555c4c947a3b80b30c/45e8840ff9b01139d41b5bca348ae473"
}

resource "cloudflare_dns_record" "edo_cname_brevo1_domainkey" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "brevo1._domainkey.enjoydevops.io"
  type    = "CNAME"
  content = "b1.enjoydevops-io.dkim.brevo.com"
  proxied = false
  ttl     = 3600
}

import {
  to = cloudflare_dns_record.edo_cname_brevo1_domainkey
  id = "c884632e448ebc555c4c947a3b80b30c/9de2a717b7b12175b867d6c271b37357"
}

resource "cloudflare_dns_record" "edo_cname_brevo2_domainkey" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "brevo2._domainkey.enjoydevops.io"
  type    = "CNAME"
  content = "b2.enjoydevops-io.dkim.brevo.com"
  proxied = false
  ttl     = 3600
}

import {
  to = cloudflare_dns_record.edo_cname_brevo2_domainkey
  id = "c884632e448ebc555c4c947a3b80b30c/b0140e381155b08a0929d925959b03c9"
}

resource "cloudflare_dns_record" "edo_cname_img" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "img.enjoydevops.io"
  type    = "CNAME"
  content = "enjoydevops-io.img.brand.brevosend.com"
  proxied = false
  ttl     = 3600
}

import {
  to = cloudflare_dns_record.edo_cname_img
  id = "c884632e448ebc555c4c947a3b80b30c/03bf1c2e409017e8e5d8a06ac4e1eb3b"
}

resource "cloudflare_dns_record" "edo_cname_r" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "r.enjoydevops.io"
  type    = "CNAME"
  content = "enjoydevops-io.r.brand.brevosend.com"
  proxied = false
  ttl     = 3600
}

import {
  to = cloudflare_dns_record.edo_cname_r
  id = "c884632e448ebc555c4c947a3b80b30c/61ce5eab98df798378a611540ea8a1e1"
}

resource "cloudflare_dns_record" "edo_cname_www" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "www.enjoydevops.io"
  type    = "CNAME"
  content = "a4eaa5fd-5853-4bb7-b30c-b6c78f24ad4b.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

import {
  to = cloudflare_dns_record.edo_cname_www
  id = "c884632e448ebc555c4c947a3b80b30c/fbd609659fdb2d2e60b9fde2028bd401"
}

resource "cloudflare_dns_record" "edo_mx_apex_route1" {
  zone_id  = data.cloudflare_zone.enjoydevops.id
  name     = "enjoydevops.io"
  type     = "MX"
  content  = "route1.mx.cloudflare.net"
  proxied  = false
  ttl      = 1
  priority = 98
}

import {
  to = cloudflare_dns_record.edo_mx_apex_route1
  id = "c884632e448ebc555c4c947a3b80b30c/eda2bec2fd2ce11cad44b789462ac534"
}

resource "cloudflare_dns_record" "edo_mx_apex_route2" {
  zone_id  = data.cloudflare_zone.enjoydevops.id
  name     = "enjoydevops.io"
  type     = "MX"
  content  = "route2.mx.cloudflare.net"
  proxied  = false
  ttl      = 1
  priority = 35
}

import {
  to = cloudflare_dns_record.edo_mx_apex_route2
  id = "c884632e448ebc555c4c947a3b80b30c/044bee39217ac12ab934c98b9bf4081d"
}

resource "cloudflare_dns_record" "edo_mx_apex_route3" {
  zone_id  = data.cloudflare_zone.enjoydevops.id
  name     = "enjoydevops.io"
  type     = "MX"
  content  = "route3.mx.cloudflare.net"
  proxied  = false
  ttl      = 1
  priority = 16
}

import {
  to = cloudflare_dns_record.edo_mx_apex_route3
  id = "c884632e448ebc555c4c947a3b80b30c/56c0c428b75d974d5593464d916c6704"
}

resource "cloudflare_dns_record" "edo_txt_apex_brevo" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "enjoydevops.io"
  type    = "TXT"
  content = "\"brevo-code:1997f075d297bfe1def7057493577b35\""
  proxied = false
  ttl     = 3600
}

import {
  to = cloudflare_dns_record.edo_txt_apex_brevo
  id = "c884632e448ebc555c4c947a3b80b30c/19a99cabaced08236135416cdddf50cf"
}

resource "cloudflare_dns_record" "edo_txt_apex_spf" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "enjoydevops.io"
  type    = "TXT"
  content = "\"v=spf1 include:_spf.mx.cloudflare.net include:spf.brevo.com ~all\""
  proxied = false
  ttl     = 1
}

import {
  to = cloudflare_dns_record.edo_txt_apex_spf
  id = "c884632e448ebc555c4c947a3b80b30c/8941cd60e2a95014fda2ab855694fc0f"
}

resource "cloudflare_dns_record" "edo_txt_cf2024_1_domainkey" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "cf2024-1._domainkey.enjoydevops.io"
  type    = "TXT"
  content = "\"v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78k\" \"m4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB\""
  proxied = false
  ttl     = 1
}

import {
  to = cloudflare_dns_record.edo_txt_cf2024_1_domainkey
  id = "c884632e448ebc555c4c947a3b80b30c/9eb0f58f6e736b9f95bdabc3da163cd2"
}

resource "cloudflare_dns_record" "edo_txt_dmarc" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "_dmarc.enjoydevops.io"
  type    = "TXT"
  content = "v=DMARC1; p=none; rua=mailto:hello@enjoydevops.io; adkim=r; aspf=r"
  proxied = false
  ttl     = 3600
  comment = "DMARC monitoring; tighten to quarantine after a few weeks of clean reports"
}

import {
  to = cloudflare_dns_record.edo_txt_dmarc
  id = "c884632e448ebc555c4c947a3b80b30c/f8a5fb59b8cbc0676715670122050d56"
}

# Free plan: a Managed Challenge on Kratos flow starts (bots can't create accounts or trigger emails) ...
resource "cloudflare_ruleset" "edo_challenge" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [{
    description = "edo: challenge sign-up, recovery and verification flow starts"
    expression  = "http.request.uri.path in {\"/auth/self-service/registration/browser\" \"/auth/self-service/recovery/browser\" \"/auth/self-service/verification/browser\"}"
    action      = "managed_challenge"
    enabled     = true
  }]
}

import {
  to = cloudflare_ruleset.edo_challenge
  id = "zones/c884632e448ebc555c4c947a3b80b30c/6c67057d9a1a41b98e865e129c630428"
}

# ... and the one free rate-limit rule on sign-in form posts (10-second window).
resource "cloudflare_ruleset" "edo_rate_limit" {
  zone_id = data.cloudflare_zone.enjoydevops.id
  name    = "default"
  kind    = "zone"
  phase   = "http_ratelimit"
  rules = [{
    description = "edo: rate limit sign-in form posts"
    expression  = "starts_with(http.request.uri.path, \"/auth/self-service/\") and http.request.method eq \"POST\""
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = 8
      mitigation_timeout  = 10
    }
  }]
}

import {
  to = cloudflare_ruleset.edo_rate_limit
  id = "zones/c884632e448ebc555c4c947a3b80b30c/33ca05d00ae24275bde4d1ee40c3a7fa"
}
