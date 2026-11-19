locals {
  cluster_endpoint = "https://${var.node_ip}:6443"

  # Disk layout on the system disk: EFI, META, STATE, EPHEMERAL (fixed size), then
  # the "data" user volume taking the rest. Every volume holding data is LUKS2
  # encrypted with a TPM key, which Talos only unseals on a Secure Boot verified boot.
  config_patches = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer = {
        image = local.installer_image
      }
      provisioning = {
        diskSelector = { match = "disk.dev_path == \"${var.install_disk}\"" }
        wipe         = true
      }
    }),
    # Single node: let workloads run on the control plane (no NoSchedule taint) and
    # do not exclude it from load balancers. The generated document is replaced.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      nodeIP     = {}
      labels     = { "node-role.kubernetes.io/control-plane" = "" }
    }),
    # Replace the generated "auto: stable" hostname with a fixed one.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = var.cluster_name
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "STATE"
      encryption = {
        provider = "luks2"
        keys     = [{ slot = 0, tpm = {} }]
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "EPHEMERAL"
      provisioning = {
        maxSize = var.ephemeral_max_size
      }
      encryption = {
        provider = "luks2"
        keys     = [{ slot = 0, tpm = {}, lockToState = true }]
      }
    }),
    # The recovery passphrase (slot 1) unlocks this volume on any Linux machine if
    # the laptop or its TPM is lost. It is deliberately not locked to STATE.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UserVolumeConfig"
      name       = "data"
      provisioning = {
        diskSelector = { match = "system_disk" }
        minSize      = "100GiB"
        grow         = true
      }
      encryption = {
        provider = "luks2"
        keys = [
          { slot = 0, tpm = {} },
          { slot = 1, static = { passphrase = local.data_recovery_passphrase } },
        ]
      }
    }),
    # Kubelets request serving certificates that include the node IP, so metrics-server can
    # verify them (approved by kubelet-serving-cert-approver).
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      extraArgs  = { "rotate-server-certificates" = "true" }
    }),
    # Cilium replaces Flannel and kube-proxy; it is installed by Talos itself at boot.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeFlannelCNIConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeProxyConfig"
      enabled    = false
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeInlineManifestConfig"
      name       = "cilium"
      manifest   = data.helm_template.cilium.manifest
    }),
  ]
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_config_contract
}

data "talos_machine_configuration" "this" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_config_contract
  kubernetes_version = var.kubernetes_version
  config_patches     = local.config_patches
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.node_ip]
  nodes                = [var.node_ip]
}

resource "talos_machine" "this" {
  node                  = var.node_ip
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.this.machine_configuration
  image                 = local.installer_image

  # Single node: there is nowhere to drain workloads to during an OS upgrade.
  drain_on_upgrade                = false
  ignore_kubernetes_upgrade_drift = true
}

resource "talos_cluster" "this" {
  node                 = var.node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = var.kubernetes_version

  depends_on = [talos_machine.this]
}

resource "talos_cluster_kubeconfig" "this" {
  node                 = var.node_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_cluster.this]
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "machine_configuration" {
  description = "Rendered machine config, for `make check-talos-config`."
  value       = data.talos_machine_configuration.this.machine_configuration
  sensitive   = true
}

data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  values = [yamlencode({
    ipam                 = { mode = "kubernetes" }
    operator             = { replicas = 1 }
    hubble               = { relay = { enabled = true }, tls = { auto = { method = "cronJob" } } }
    kubeProxyReplacement = true
    k8sServiceHost       = "localhost"
    k8sServicePort       = 7445
    cgroup               = { autoMount = { enabled = false }, hostRoot = "/sys/fs/cgroup" }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
  })]
}
