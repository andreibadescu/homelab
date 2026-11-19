variable "cluster_name" {
  description = "Name of the Talos/Kubernetes cluster and hostname of the node."
  type        = string
  default     = "homelab"
}

variable "node_ip" {
  description = "LAN address of the node (DHCP reservation in the router)."
  type        = string
  default     = "192.168.1.136"
}

variable "install_disk" {
  description = "Disk Talos installs to. It is wiped on first install."
  type        = string
  default     = "/dev/nvme0n1"
}

variable "talos_version" {
  description = "Talos release installed on the node. Changing it upgrades the node in place."
  type        = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "v1.14.6"
}

variable "talos_config_contract" {
  description = "Talos machine config contract. Pinned to the version the cluster was created with; do not bump on upgrades."
  type        = string
  default     = "v1.14"
}

variable "kubernetes_version" {
  description = "Kubernetes release. Changing it runs Talos's upgrade-k8s procedure."
  type        = string
  # renovate: datasource=github-releases depName=kubernetes/kubernetes
  default = "v1.37.2"
}

variable "ephemeral_max_size" {
  description = "Size of the EPHEMERAL volume (Kubernetes, images, etcd). The rest of the disk goes to the data volume."
  type        = string
  default     = "50GiB"
}

variable "talos_extensions" {
  description = "Official Talos system extensions baked into the image. Tailscale runs as a Kubernetes operator instead: an unconfigured extension service keeps Talos in the booting stage."
  type        = list(string)
  default = [
    "siderolabs/intel-ucode",
    "siderolabs/i915",
  ]
}

variable "github_owner" {
  description = "GitHub account that owns the repository."
  type        = string
  default     = "andreibadescu"
}

variable "github_repository" {
  description = "Repository Flux syncs from (this repository)."
  type        = string
  default     = "homelab"
}

variable "flux_version" {
  description = "Flux release installed in the cluster."
  type        = string
  # renovate: datasource=github-releases depName=fluxcd/flux2
  default = "v2.10.0"
}

variable "cilium_version" {
  description = "Cilium (CNI) chart version, installed by Talos as an inline manifest."
  type        = string
  # renovate: datasource=github-releases depName=cilium/cilium
  default = "1.20.5"
}
