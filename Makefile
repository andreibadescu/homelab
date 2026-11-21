# Tools come from mise (mise.toml), pinned exactly: run `make tools` once, then any target. No container:
# commands run on the Mac (or CI) with the pinned tools first on PATH.

CRED_DIR ?= $(HOME)/.homelab
AGE_KEY  ?= $(HOME)/Library/Application Support/sops/age/keys.txt
TOFU     := mise x -- tofu -chdir=tofu

export PATH := $(shell mise bin-paths 2>/dev/null | tr '\n' ':')$(PATH)
export SOPS_AGE_KEY_FILE := $(AGE_KEY)
export CRED_DIR

# OpenTofu manages the Flux deploy key on GitHub with the gh CLI login, passed only
# through the environment.
export GITHUB_TOKEN ?= $(shell gh auth token 2>/dev/null)

.PHONY: tools shell hooks mac-dns init upgrade lock fmt validate check restic tenant-kubeconfig plan apply rebuild output creds check-talos-config sync-manifests

# Install the pinned tools (mise.toml). Run once per machine and after a version bump.
tools:
	mise install

# A shell with the pinned tools on PATH and the age key set (for sops -d and the like).
shell:
	@mise x -- bash

# Once per clone: run `make check` automatically before every push
# (.githooks/pre-push). Links the hook into .git/hooks; doesn't change any git configuration.
hooks:
	ln -sf ../../.githooks/pre-push .git/hooks/pre-push
	@echo "pre-push hook installed: git push now runs make check first (skip once: git push --no-verify)"

# On the admin Mac: send only *.ts.net lookups to Tailscale's resolver, leaving
# the Mac's other DNS alone. Asks for your password (sudo). Undo: sudo rm /etc/resolver/ts.net
mac-dns:
	sudo mkdir -p /etc/resolver
	echo "nameserver 100.100.100.100" | sudo tee /etc/resolver/ts.net >/dev/null
	@echo "*.ts.net now resolves through Tailscale"

init:
	$(TOFU) init

upgrade:
	$(TOFU) init -upgrade

# Record provider hashes for every platform the repo is run on.
lock:
	$(TOFU) providers lock -platform=linux_arm64 -platform=linux_amd64 -platform=darwin_arm64

fmt:
	$(TOFU) fmt -recursive

validate:
	$(TOFU) validate

# Every repository check (OpenTofu, Kubernetes schemas, encrypted secrets, lint, gitleaks).
# CI runs the same target.
check:
	scripts/check.sh

# restic against an app's backup repository; works without the cluster.
# Example: make restic APP=ente ARGS="snapshots"
restic:
	scripts/restic.sh "$(APP)" $(ARGS)

# Kubeconfig for a project's build agent, limited to its builds namespace (docs/builds.md).
# Example: make tenant-kubeconfig TENANT=enjoydevops
tenant-kubeconfig:
	scripts/tenant-kubeconfig.sh "$(TENANT)" "$(or $(ACCOUNT),builder)"

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply

# Install and bootstrap a node that is in maintenance mode again (after the reset procedure in
# docs/recovery.md, or a reinstall from the USB stick), reusing the cluster's existing secrets.
# Flux redeploys itself (its provider sees it is missing) and its decryption key follows.
rebuild:
	$(TOFU) apply -replace=talos_machine.this -replace=talos_cluster.this -replace=talos_cluster_kubeconfig.this
	$(MAKE) creds

output:
	$(TOFU) output

# Write the admin credentials outside the repo, readable only by you.
creds:
	@mkdir -p "$(CRED_DIR)" && chmod 700 "$(CRED_DIR)"
	@umask 077 && $(TOFU) output -raw talosconfig > $(CRED_DIR)/talosconfig
	@umask 077 && $(TOFU) output -raw kubeconfig > $(CRED_DIR)/kubeconfig
	@echo "wrote ~/.homelab/talosconfig and ~/.homelab/kubeconfig"
	@k=$$(grep client-certificate-data $(CRED_DIR)/kubeconfig | awk '{print $$2}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2); \
	t=$$(grep -m1 -E '^\s+crt:' $(CRED_DIR)/talosconfig | awk '{print $$2}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2); \
	python3 -c 'import sys,re,datetime as d; f=lambda x: d.datetime.strptime(x, "%b %d %H:%M:%S %Y %Z").strftime("%Y-%m-%d"); p="credential-expiry.yaml"; s=open(p).read(); s=re.sub(r"(?m)^kubeconfig: .*", "kubeconfig: "+f(sys.argv[1]), s); s=re.sub(r"(?m)^talosconfig: .*", "talosconfig: "+f(sys.argv[2]), s); open(p,"w").write(s)' "$$k" "$$t"
	@grep -E '^(kubeconfig|talosconfig):' credential-expiry.yaml

# Validate the rendered machine config with Talos's own validator. The config holds secrets, so it
# is streamed through a pipe and never written to disk.
check-talos-config:
	@bash -c 'talosctl validate --mode metal --strict --config <($(TOFU) output -raw machine_configuration)'

# Talos applies its built-in manifests (Cilium, CoreDNS) only at bootstrap. After changing them
# (for example a new cilium_version) and running `make apply`, push them to the cluster with this.
# It shows a dry run first, then asks before applying.
sync-manifests:
	@K8S=$$(grep -A4 'variable "kubernetes_version"' tofu/variables.tf | sed -n 's/.*default *= *"\(.*\)"/\1/p'); \
	talosctl --talosconfig $(CRED_DIR)/talosconfig upgrade-k8s --to $$K8S --dry-run && \
	read -p "Apply these changes? [y/N] " a && [ "$$a" = y ] && \
	talosctl --talosconfig $(CRED_DIR)/talosconfig upgrade-k8s --to $$K8S

