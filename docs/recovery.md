# Recovery

## Disk layout

| Volume | Partition | Holds | Unlocked by |
|---|---|---|---|
| EFI, META | p1, p2 | Signed boot files, small settings | Not encrypted (no data) |
| STATE | p3 | Talos machine config | TPM (PCR 7 + signed PCR 11) |
| EPHEMERAL | p4 (50 GiB) | Kubernetes, images, etcd | TPM, locked to STATE |
| data | p5 (rest) | Important files, mounted at `/var/mnt/data` | TPM, **or the recovery passphrase** |

The TPM only releases keys to a Secure Boot verified, Sidero-signed Talos boot on this laptop.

## The recovery passphrase

Stored encrypted in `tofu/secrets.sops.yaml`. Copy it to a password manager (macOS):

```bash
make shell
sops -d --extract '["data_recovery_passphrase"]' tofu/secrets.sops.yaml   # copy, then clear the terminal
```

Without the age key (`~/Library/Application Support/sops/age/keys.txt`) nothing in the repo can
be decrypted. Keep the age key in the password manager too.

## Read the data volume on another Linux machine

Use this if the laptop, its motherboard or its TPM is lost, or the TPM refuses to unlock.

```bash
lsblk -o NAME,SIZE,PARTLABEL,FSTYPE          # the data partition has PARTLABEL u-data
sudo cryptsetup open /dev/<disk>p5 homelab-data   # asks for the recovery passphrase
sudo mount -o ro /dev/mapper/homelab-data /mnt    # XFS
# copy what you need, then:
sudo umount /mnt && sudo cryptsetup close homelab-data
```

## Change the disk layout, remotely (tested 2026-11-19)

Talos never resizes an existing volume, but it recreates missing ones at the configured size.
`talosctl reset --system-labels-to-wipe` wipes **and drops** the listed partitions while keeping
EFI and META, so the node reboots from its own disk into maintenance mode. No USB stick needed.

1. Change the sizes in `tofu/variables.tf`.
2. Wipe STATE and EPHEMERAL (this also clears the STATE encryption settings in META):
   `talosctl --talosconfig ~/.homelab/talosconfig reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot --wait=false`
3. Wait for maintenance mode: `talosctl -n <node-ip> get machinestatus --insecure`
4. Only if the data volume must change size too (**this destroys the files on it**: restore from backup
   afterwards). Otherwise skip, and it is found again by its label:
   `talosctl -n <node-ip> wipe disk nvme0n1p5 --drop-partition --insecure`
5. Follow [Rebuild the cluster](#rebuild-the-cluster) from step 1 (remove the old Tailscale
   devices, then `make rebuild`).

## Before a BIOS update or a Secure Boot key change

These change PCR 7, so the TPM will no longer unlock STATE and EPHEMERAL. Run steps 2, 3 and 5
above around the update: wipe STATE and EPHEMERAL before it, update, then rebuild. The data volume
is kept and is expected to unlock with the recovery passphrase, after which Talos re-adds a TPM key
for the new measurements (this last part is not yet rehearsed).

Do not use the USB stick's **Reset system disk** entry for this: it wipes the whole Talos system
disk, including the data volume.

## Rebuild the cluster

Use this when the node is in maintenance mode again: after the reset above (the data volume is kept),
or after a reinstall from the USB stick (**the whole disk is wiped, including the data volume**).

1. In the homelab tailnet's admin console, **remove the old devices** (`ente-*`, `homelab-operator`
   and any other app). Otherwise the new ones get names like `ente-api-1` and the app addresses
   break. People keep their shares only if you share the new devices again.
2. `make rebuild`. It installs Talos, bootstraps Kubernetes with the cluster's existing secrets,
   redeploys Flux (and its decryption key) and writes new admin credentials. On a reinstall, unplug
   the USB stick when the node reboots. (The Talos part was rehearsed on 2026-11-19, before Flux
   existed; the Flux redeploy relies on the Flux provider noticing Flux is missing, which its code
   does, but has not been rehearsed yet.)
3. Flux deploys everything from Git within a few minutes: `flux get kustomizations -A`.
4. App data:
   - **Data volume kept**: volumes live in `<namespace>/<claim>/` folders, so the recreated claims
     find their data again by themselves: Ente, the registry's images, projects' databases.
   - **Disk wiped**:
     - Ente: restore from its backups (`docs/backups.md`).
     - Projects' databases (CloudNativePG): each project restores its cluster from its point-in-time
       archive in R2, from its own repository (`docs/databases.md`).
     - The registry starts empty. Public images come back through its cache (or straight from the
       internet: the node falls back), and the platform's Kaniko image is rebuilt by its Job. Projects
       rebuild their own images (EnjoyDevOps: `make images` and `make lab-images` in its repository)
       before their pods can start.
5. Re-share the app devices in Tailscale if step 1 removed shared ones.
6. Project agents need new kubeconfigs (`make tenant-kubeconfig TENANT=<project>`): the old tokens belong
   to the old cluster.

## Network layer (Cilium)

Cilium is rendered by OpenTofu (`data.helm_template.cilium`, version `cilium_version` in
`tofu/variables.tf`) and installed by Talos as an inline manifest, so a rebuilt node gets it before Flux
starts. Talos applies inline manifests only at bootstrap: after changing the Cilium version or values,
run `make apply`, then `make sync-manifests` (dry run first, then asks).
