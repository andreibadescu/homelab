terraform {
  required_version = ">= 1.13"

  # State lives next to the code, encrypted. Without the age key it cannot be read.
  backend "local" {
    path = "terraform.tfstate"
  }

  encryption {
    key_provider "external" "sops" {
      command = ["./state-key.sh"]
    }

    method "aes_gcm" "sops" {
      keys = key_provider.external.sops
    }

    state {
      method   = method.aes_gcm.sops
      enforced = true
    }

    plan {
      method   = method.aes_gcm.sops
      enforced = true
    }
  }

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.10.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.30.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.29.0"
    }
  }
}
