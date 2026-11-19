#!/bin/sh
# OpenTofu external key provider: returns the state encryption key stored in
# secrets.sops.yaml, decrypted with the local age key. Protocol:
# https://opentofu.org/docs/language/state/encryption/#external
set -eu
echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'
INPUT="$(cat)"
KEY="$(sops -d --extract '["state_encryption_key"]' "$(dirname "$0")/secrets.sops.yaml")"
if [ "$INPUT" = "null" ]; then
  printf '{"keys":{"encryption_key":"%s"},"meta":{"external_data":{}}}\n' "$KEY"
else
  printf '{"keys":{"encryption_key":"%s","decryption_key":"%s"},"meta":{"external_data":{}}}\n' "$KEY" "$KEY"
fi
