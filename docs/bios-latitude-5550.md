# Dell Latitude 5550 BIOS checklist

The only manual step. Do it once per machine, before the first boot into Talos.
Press F2 at the Dell logo, and switch on **Advanced Setup** at the bottom of the screen
so every setting is visible. Use the search box if a setting is not where listed.

## 1. Storage

| Setting | Value | Why |
|---|---|---|
| Storage → SATA/NVMe Operation | **AHCI/NVMe** | Talos cannot always see the disk in "RAID On" (Intel VMD) mode |

## 2. TPM

| Setting | Value |
|---|---|
| Security → TPM 2.0 Security On | ON |
| TPM State | Enabled |
| Attestation Enable / Key Storage Enable / SHA-256 | ON |
| Clear | **Do not use**: clearing the TPM destroys the disk encryption keys |
| Absolute | Leave as is. Never choose "Permanently Disable" |

## 3. Secure Boot: enroll the Talos keys

Talos images from the Image Factory are signed by Sidero Labs. The firmware is given the Sidero
keys (PK, KEK, db) by the Talos boot menu, so afterwards **only Sidero-signed Talos images boot**.

1. Boot Configuration → Secure Boot → Expert Key Management: Enable Custom Mode **ON**, then
   **Delete All Keys**. The firmware enters Setup Mode and Secure Boot Mode drops to Audit.
2. Apply, exit, **F12 → USB stick** (section 4).
3. In the Talos menu press the down arrow (this stops the 10-second countdown), select
   **Enroll Secure Boot keys: auto** and press Enter. On the warning countdown that follows,
   **do not press any key**: it enrolls the keys and restarts.
4. F2 again: Secure Boot Mode **Deployed Mode**, Enable Secure Boot **ON**. Apply.
5. F12 → USB stick → **Talos (vX.Y.Z)** (the first entry, never "Reset system disk").
6. Verify from the Mac: `talosctl -n <node-ip> get securitystate --insecure` shows `secureBoot: true`.

Undo (for example to reinstall Windows): Expert Key Management → **Reset All Keys** restores the
Dell and Microsoft keys.

Changing the keys or updating the BIOS can change the TPM measurement (PCR 7). The node then
cannot unlock STATE and EPHEMERAL; see [recovery.md](recovery.md) before doing either.

## 4. Boot media: USB stick

The node boots the Talos installer from a USB stick holding the SecureBoot ISO
(`make output` → `iso_secureboot_url`). Write it from macOS Terminal:

```bash
diskutil list external physical          # find the stick, e.g. disk4
curl -fLo talos-secureboot.iso "<iso_secureboot_url>"
diskutil unmountDisk /dev/diskN
sudo dd if=talos-secureboot.iso of=/dev/rdiskN bs=4m status=progress && sync && diskutil eject /dev/diskN
```

The stick does not need rewriting after Talos upgrades: it only starts maintenance mode, and the node
installs whatever version `tofu/variables.tf` specifies.

| Setting | Value |
|---|---|
| Boot Configuration → Enable USB Boot Support | **ON** |
| Connection → HTTP(s) Boot | **OFF** (not used; a failed network boot only delays startup) |

## 5. Power (it is a server)

| Setting | Value |
|---|---|
| Power → AC Behavior | **Power On** (restart after a power cut) |
| Power → Battery Configuration | **Primarily AC Use** (protects a battery that is always plugged in) |

## 6. Dell recovery features

After a few failed boots the firmware starts SupportAssist OS Recovery and offers to download Dell's
recovery OS to repair Windows. That would block the unattended fall-through to the USB stick.

| Setting (Update, Recovery) | Value |
|---|---|
| SupportAssist OS Recovery | **OFF** |
| BIOSConnect | **OFF** |
| Dell Auto OS Recovery Threshold | **OFF** |
| UEFI Capsule Firmware Updates | ON (keeps BIOS updates working) |

If the SupportAssist screen appears, choose **Cancel**.

## 7. Boot order (this makes rebuilds automatic)

Boot Configuration → Boot Sequence:

1. **Internal disk** (the Talos entry, once installed)
2. **USB stick**

Leave the stick plugged in. Remove the stale "Windows Boot Manager" entry once Windows is gone.
Never put the USB stick first: the node would boot the installer instead of the installed system.

With this order an empty disk falls through to the stick, so a wiped node comes back in Talos
maintenance mode on its own and `make apply` reinstalls it. For the very first install, while the
old OS is still on the disk, use **F12 → USB stick** once.

## 8. Admin password (do this last, once everything works)

| Password | Set it? | Why |
|---|---|---|
| Admin / Setup | **Yes** | Stops anyone changing Secure Boot, the keys or the TPM |
| System / Boot | **No** | Would stop the server starting by itself after a power cut |
| Internal drive | **No** | Same; TPM encryption already protects the disk |

Store it in a password manager. Removing the battery does not reset it.

## Verify (from the Mac)

```bash
talosctl -n <node-ip> get securitystate --insecure   # secureBoot: true
```
