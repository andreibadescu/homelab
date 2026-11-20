FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends age bzip2 ca-certificates curl git make unzip jq less openssh-client shellcheck yamllint \
 && rm -rf /var/lib/apt/lists/*

# renovate: datasource=github-releases depName=opentofu/opentofu
ARG TOFU_VERSION=1.13.9
# renovate: datasource=github-releases depName=siderolabs/talos
ARG TALOSCTL_VERSION=1.14.6
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=1.37.2
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=4.3.2
# renovate: datasource=github-releases depName=fluxcd/flux2
ARG FLUX_VERSION=2.10.0
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=3.13.3

# renovate: datasource=github-releases depName=yannh/kubeconform
ARG KUBECONFORM_VERSION=0.8.0
# renovate: datasource=github-releases depName=rhysd/actionlint
ARG ACTIONLINT_VERSION=1.7.12
# renovate: datasource=github-releases depName=gitleaks/gitleaks
ARG GITLEAKS_VERSION=8.30.1
# renovate: datasource=github-releases depName=restic/restic
ARG RESTIC_VERSION=0.20.0

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
WORKDIR /tmp/dl

RUN ARCH="$(dpkg --print-architecture)" \
 && curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${ARCH}.tar.gz" \
 && curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_SHA256SUMS" | grep "_linux_${ARCH}.tar.gz$" | sha256sum -c - \
 && tar -xzf "tofu_${TOFU_VERSION}_linux_${ARCH}.tar.gz" -C /usr/local/bin tofu \
 \
 && curl -fsSLo talosctl "https://github.com/siderolabs/talos/releases/download/v${TALOSCTL_VERSION}/talosctl-linux-${ARCH}" \
 && echo "$(curl -fsSL "https://github.com/siderolabs/talos/releases/download/v${TALOSCTL_VERSION}/sha256sum.txt" | awk -v f="talosctl-linux-${ARCH}" '$2==f{print $1}')  talosctl" | sha256sum -c - \
 && install -m 0755 talosctl /usr/local/bin/talosctl \
 \
 && curl -fsSLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
 && echo "$(curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256")  kubectl" | sha256sum -c - \
 && install -m 0755 kubectl /usr/local/bin/kubectl \
 \
 && curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz" \
 && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum" | sha256sum -c - \
 && tar -xzf "helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz" --strip-components=1 -C /usr/local/bin "linux-${ARCH}/helm" \
 \
 && curl -fsSLO "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${ARCH}.tar.gz" \
 && curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_checksums.txt" | grep "_linux_${ARCH}.tar.gz" | sha256sum -c - \
 && tar -xzf "flux_${FLUX_VERSION}_linux_${ARCH}.tar.gz" -C /usr/local/bin flux \
 \
 && curl -fsSLo sops "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${ARCH}" \
 && echo "$(curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt" | awk -v f="sops-v${SOPS_VERSION}.linux.${ARCH}" '$2==f{print $1}')  sops" | sha256sum -c - \
 && install -m 0755 sops /usr/local/bin/sops \
 \
 \
 && curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${ARCH}.tar.gz" \
 && curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/CHECKSUMS" | grep " kubeconform-linux-${ARCH}.tar.gz$" | sha256sum -c - \
 && tar -xzf "kubeconform-linux-${ARCH}.tar.gz" -C /usr/local/bin kubeconform \
 \
 && curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${ARCH}.tar.gz" \
 && curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_checksums.txt" | grep " actionlint_${ACTIONLINT_VERSION}_linux_${ARCH}.tar.gz$" | sha256sum -c - \
 && tar -xzf "actionlint_${ACTIONLINT_VERSION}_linux_${ARCH}.tar.gz" -C /usr/local/bin actionlint \
 \
 && GL_ARCH="$([ "$ARCH" = amd64 ] && echo x64 || echo "$ARCH")" \
 && curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GL_ARCH}.tar.gz" \
 && curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" | grep " gitleaks_${GITLEAKS_VERSION}_linux_${GL_ARCH}.tar.gz$" | sha256sum -c - \
 && tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_${GL_ARCH}.tar.gz" -C /usr/local/bin gitleaks \
 \
 \
 && curl -fsSLO "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_${ARCH}.bz2" \
 && curl -fsSL "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/SHA256SUMS" | grep " restic_${RESTIC_VERSION}_linux_${ARCH}.bz2$" | sha256sum -c - \
 && bunzip2 -c "restic_${RESTIC_VERSION}_linux_${ARCH}.bz2" > /usr/local/bin/restic && chmod 755 /usr/local/bin/restic \
 \
 && rm -rf /tmp/dl

ENV HOMELAB_TOOLBOX=1
WORKDIR /workspace
