# External services

Their configuration is code wherever an API allows it (`tofu/tailscale.tf`, `tofu/cloudflare.tf`,
`tofu/github.tf`, `tofu/healthchecks.tf`).
What is left here are the one-time steps no API covers: creating accounts and the credentials that
OpenTofu and the cluster use.

## Tailscale (homelab tailnet)

A tailnet of its own, created with a separate login, holding only the cluster's devices. Code:
`tofu/tailscale.tf` applies the access policy (`tofu/tailscale-policy.hujson`) and MagicDNS.

1. **DNS → Enable HTTPS** (certificates for `*.<tailnet>.ts.net`; no API for this switch). Optionally
   rename the tailnet first (DNS → Rename tailnet); `kubernetes/` uses `junco-ulmer.ts.net`.
2. **Two OAuth clients** (Settings → Trust credentials → OAuth):
   - `homelab-operator`, for the Tailscale operator in the cluster: scopes **Services**,
     **Devices → Core** and **Keys → Auth Keys** (read and write), tag `tag:k8s-operator`. Stored as
     `kubernetes/infrastructure/tailscale/operator-oauth.sops.yaml` (Secret `operator-oauth`, keys
     `client_id` and `client_secret`).
   - `homelab-opentofu`, for OpenTofu: scopes **Policy File** and **DNS** only (read and write).
     Stored as `tailscale_oauth_client_id` and `tailscale_oauth_client_secret` in
     `tofu/secrets.sops.yaml`.
   Before the first `make apply`, paste the policy file into the access controls editor once, so the
   operator's tags exist; afterwards OpenTofu keeps it in sync.
3. **Sharing**: Machines → app device → Share, to each person's own Tailscale account. They reach
   that device and nothing else. Never share `homelab-operator`.

## Cloudflare (public showcase)

The zone `andreibadescu.com` is on the Cloudflare account. Code: `tofu/cloudflare.tf` creates the
tunnel and its routes, the DNS record, the rate limit, the redirect, and the connector's namespace and
token Secret in the cluster.

1. **API token** (My Profile → API Tokens → Create Token → Create Custom Token), name
   `homelab-opentofu`:
   - zone policy for `andreibadescu.com` (and `enjoydevops.io`, for later): **Zone Read**,
     **DNS Edit**, **Zone WAF Edit**, **Single Redirect Edit**;
   - account policy: **Cloudflare Tunnel Edit**;
   - expiry one year; the date is in `credential-expiry.yaml`, which opens a reminder issue.
2. Store it as `cloudflare_api_token` in `tofu/secrets.sops.yaml`.

## Alerts

- **ntfy** (ntfy.sh, no account): the topic is in
  `kubernetes/infrastructure/monitoring/alertmanager-notify.sops.yaml` (`ntfy-url`). Subscribe to it
  in the ntfy app. To rotate, write a new random topic there and resubscribe.
- **healthchecks.io** (free): the check `homelab` is code (`tofu/healthchecks.tf`). By hand, once:
  the account, an **ntfy** integration (server `https://ntfy.sh`, same topic, "down" priority high)
  and an **email** integration (integrations have no API), and a read-write API key stored as
  `healthchecks_api_key` in `tofu/secrets.sops.yaml`. If the check is ever recreated, copy its new
  ping URL (`tofu show -json`, attribute `ping_url`) into `healthchecks-url` in
  `alertmanager-notify.sops.yaml`; the URL works like a password, so it never goes into the code.

## GitHub

- The repository's settings, the protection of `main`, vulnerability alerts and the Flux deploy key are
  code (`tofu/github.tf`, `tofu/flux.tf`); OpenTofu uses the `gh` CLI login.
- **Renovate**: the Mend Renovate app, plan "Renovate Only", mode "Scan and Alert", installed on
  this repository only.
