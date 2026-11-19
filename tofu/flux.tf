# The GitHub token is read from the GITHUB_TOKEN environment variable (see Makefile).
provider "github" {
  owner = var.github_owner
}

locals {
  kube = talos_cluster_kubeconfig.this.kubernetes_client_configuration
}

provider "flux" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = base64decode(local.kube.ca_certificate)
    client_certificate     = base64decode(local.kube.client_certificate)
    client_key             = base64decode(local.kube.client_key)
  }
  git = {
    url    = "ssh://git@github.com/${var.github_owner}/${var.github_repository}.git"
    branch = "main"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

# Deploy key used by Flux to read the repository (and to commit its own manifests at bootstrap).
resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "flux" {
  title      = "flux-${var.cluster_name}"
  repository = var.github_repository
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

resource "flux_bootstrap_git" "this" {
  path               = "kubernetes/clusters/${var.cluster_name}"
  version            = var.flux_version
  embedded_manifests = true

  depends_on = [github_repository_deploy_key.flux, talos_cluster.this]
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = base64decode(local.kube.ca_certificate)
  client_certificate     = base64decode(local.kube.client_certificate)
  client_key             = base64decode(local.kube.client_key)
}

# Private age key Flux uses to decrypt *.sops.yaml secrets under kubernetes/.
resource "kubernetes_secret_v1" "sops_age" {
  metadata {
    name      = "sops-age"
    namespace = "flux-system"
  }
  data = {
    "age.agekey" = data.sops_file.secrets.data["flux_age_key"]
  }

  depends_on = [flux_bootstrap_git.this]
}
