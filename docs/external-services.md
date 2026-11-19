# External services (set up by hand)

Everything in the cluster is code. These accounts and settings live outside it and are set up once.

## Tailscale (homelab tailnet)

A tailnet of its own, created with a separate login, holding only the cluster's devices.

1. **DNS**: MagicDNS on, then **Enable HTTPS** (certificates for `*.<tailnet>.ts.net`). Optionally
   rename the tailnet first (DNS → Rename tailnet); `kubernetes/` uses `junco-ulmer.ts.net`.
2. **Access controls** (JSON editor), the whole policy:
   ```json
   {
     "tagOwners": {
       "tag:k8s-operator": ["autogroup:admin"],
       "tag:k8s": ["tag:k8s-operator"]
     },
     "grants": [
       {"src": ["autogroup:member", "autogroup:shared"], "dst": ["tag:k8s"], "ip": ["tcp:443"]}
     ]
   }
   ```
3. **Settings → Trust credentials → OAuth**, description `homelab-operator`, scopes **Services**,
   **Devices → Core** and **Keys → Auth Keys** (read and write), tag `tag:k8s-operator` on each. Store
   the client ID and secret as `kubernetes/infrastructure/tailscale/operator-oauth.sops.yaml`
   (a Secret `operator-oauth` in namespace `tailscale` with keys `client_id` and `client_secret`).
4. **Sharing**: Machines → app device → Share, to each person's own Tailscale account. They reach
   that device and nothing else. Never share `homelab-operator`.

## Cloudflare (public showcase)

The tunnel was created once with the `cloudflared` login for `andreibadescu.com`:

```bash
cloudflared tunnel create --credentials-file homelab-tunnel.json homelab
cloudflared tunnel route dns homelab homelab.andreibadescu.com
```

The credentials file went into `kubernetes/apps/showcase/cloudflared-credentials.sops.yaml` (key
`credentials.json`) and was deleted. The tunnel ID (7f2e12dd-754d-4c6a-a378-02e7fc87bbe0) is in `cloudflared-config.yaml`. To rebuild on
another account, create a new tunnel the same way and replace both.

## Alerts

- **ntfy** (ntfy.sh, no account): the topic is in
  `kubernetes/infrastructure/monitoring/alertmanager-notify.sops.yaml` (`ntfy-url`). Subscribe to it
  in the ntfy app. To rotate, write a new random topic there and resubscribe.
- **healthchecks.io** (free): an ntfy integration (server `https://ntfy.sh`, same topic, "down"
  priority high) and a check `homelab` (period 5 minutes, grace 10 minutes). Its ping URL is
  `healthchecks-url` in the same SOPS file.

## GitHub

- Repository `homelab` with the Flux deploy key (created by OpenTofu).
- **Renovate**: the Mend Renovate app, plan "Renovate Only", mode "Scan and Alert", installed on
  this repository only.
