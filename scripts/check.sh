#!/usr/bin/env bash
# All repository checks; run inside the toolbox (`make check`), locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
step() { printf '\n== %s\n' "$*"; }

step "OpenTofu: format and validate"
tofu -chdir=tofu fmt -check -recursive
work=$(mktemp -d)
cp -r tofu/. "$work"
rm -f "$work/terraform.tfstate"
tofu -chdir="$work" init -backend=false -input=false >/dev/null
tofu -chdir="$work" validate
rm -rf "$work"

step "Kubernetes: render and validate against schemas"
out=$(mktemp --suffix .yaml)
for dir in kubernetes/infrastructure kubernetes/apps kubernetes/clusters/homelab/flux-system; do
  kubectl kustomize "$dir" >>"$out"
  echo "---" >>"$out"
done
for file in kubernetes/clusters/homelab/*.yaml; do
  cat "$file" >>"$out"
  echo "---" >>"$out"
done
kubeconform -strict -summary -skip Secret,CustomResourceDefinition \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  "$out"
rm -f "$out"

step "Secrets: every Secret and *.sops.yaml file is SOPS-encrypted"
failed=0
while IFS= read -r file; do
  case "$file" in
    *.sops.yaml) ;;
    *)
      # Allowed: service-account-token Secrets with no data (Kubernetes fills them in).
      if grep -q '^type: kubernetes.io/service-account-token$' "$file" && ! grep -q -E '^(data|stringData):' "$file"; then
        continue
      fi
      echo "plaintext Secret outside a *.sops.yaml file: $file"; failed=1 ;;
  esac
done < <(grep -rl --include='*.yaml' -E '^kind: Secret$' kubernetes || true)
while IFS= read -r file; do
  if ! grep -q '^sops:' "$file" || ! grep -q 'ENC\[AES256_GCM' "$file"; then
    echo "not encrypted: $file"
    failed=1
  fi
done < <(git ls-files "*.sops.yaml" | grep -v "^.sops.yaml$")
[ "$failed" -eq 0 ] && echo "ok"
[ "$failed" -eq 0 ]

step "Lint: YAML, shell scripts, GitHub workflows"
yamllint --strict .
shellcheck scripts/*.sh tofu/*.sh
actionlint

step "Secrets in git history (gitleaks)"
git config --global --add safe.directory "$PWD" 2>/dev/null || true
gitleaks git --no-banner --redact .
