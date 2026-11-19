# Every target runs inside the toolbox container (.devcontainer/Dockerfile), so the
# host only needs Docker and make. Inside the container HOMELAB_TOOLBOX=1 is set and
# the targets run directly.

IMAGE    := homelab-toolbox
CRED_DIR ?= $(HOME)/.homelab
AGE_KEY  ?= $(HOME)/Library/Application Support/sops/age/keys.txt
TOFU     := tofu -chdir=tofu

TARGETS := init upgrade lock fmt validate check plan apply rebuild output creds check-talos-config sync-manifests

# OpenTofu manages the Flux deploy key on GitHub with the gh CLI login, passed only
# through the environment.
export GITHUB_TOKEN ?= $(shell gh auth token 2>/dev/null)

ifndef HOMELAB_TOOLBOX

.PHONY: toolbox shell mac-dns $(TARGETS)

toolbox:
	docker build -q -t $(IMAGE) .devcontainer >/dev/null

DOCKER_RUN = docker run --rm -i $(shell test -t 0 && echo -t) \
	-v "$(CURDIR)":/workspace \
	-v "$(CRED_DIR)":/root/.homelab \
	-v "$(AGE_KEY)":/root/.config/sops/age/keys.txt:ro \
	-e GITHUB_TOKEN \
	$(IMAGE)

# On the admin Mac (not in the toolbox): send only *.ts.net lookups to Tailscale's resolver, leaving
# the Mac's other DNS alone. Asks for your password (sudo). Undo: sudo rm /etc/resolver/ts.net
mac-dns:
	sudo mkdir -p /etc/resolver
	echo "nameserver 100.100.100.100" | sudo tee /etc/resolver/ts.net >/dev/null
	@echo "*.ts.net now resolves through Tailscale"

shell: toolbox
	@mkdir -p "$(CRED_DIR)" && chmod 700 "$(CRED_DIR)"
	$(DOCKER_RUN) bash

$(TARGETS): toolbox
	@mkdir -p "$(CRED_DIR)" && chmod 700 "$(CRED_DIR)"
	$(DOCKER_RUN) make $@

else

.PHONY: $(TARGETS)

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
	@umask 077 && $(TOFU) output -raw talosconfig > /root/.homelab/talosconfig
	@umask 077 && $(TOFU) output -raw kubeconfig > /root/.homelab/kubeconfig
	@echo "wrote ~/.homelab/talosconfig and ~/.homelab/kubeconfig"
	@k=$$(grep client-certificate-data /root/.homelab/kubeconfig | awk '{print $$2}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2); \
	t=$$(grep -m1 -E '^\s+crt:' /root/.homelab/talosconfig | awk '{print $$2}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2); \
	sed -i -E "s/^kubeconfig: .*/kubeconfig: $$(date -u -d "$$k" +%F)/; s/^talosconfig: .*/talosconfig: $$(date -u -d "$$t" +%F)/" credential-expiry.yaml
	@grep -E '^(kubeconfig|talosconfig):' credential-expiry.yaml

# Validate the rendered machine config with Talos's own validator. The config holds
# secrets, so it only ever touches the container's RAM disk.
check-talos-config:
	@umask 077 && $(TOFU) output -raw machine_configuration > /dev/shm/mc.yaml
	@talosctl validate --mode metal --strict --config /dev/shm/mc.yaml; rc=$$?; rm -f /dev/shm/mc.yaml; exit $$rc

# Talos applies its built-in manifests (Cilium, CoreDNS) only at bootstrap. After changing them
# (for example a new cilium_version) and running `make apply`, push them to the cluster with this.
# It shows a dry run first, then asks before applying.
sync-manifests:
	@K8S=$$(grep -A4 'variable "kubernetes_version"' tofu/variables.tf | sed -n 's/.*default *= *"\(.*\)"/\1/p'); \
	talosctl --talosconfig /root/.homelab/talosconfig upgrade-k8s --to $$K8S --dry-run && \
	read -p "Apply these changes? [y/N] " a && [ "$$a" = y ] && \
	talosctl --talosconfig /root/.homelab/talosconfig upgrade-k8s --to $$K8S

endif
