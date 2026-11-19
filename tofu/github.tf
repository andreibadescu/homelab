# This repository's settings and the protection of main. (The Flux deploy key is in flux.tf.)
resource "github_repository" "homelab" {
  name         = var.github_repository
  description  = "Talos Kubernetes homelab managed as code: OpenTofu, Flux, Cilium, SOPS, Tailscale, Grafana, Loki, Tempo, OpenTelemetry"
  homepage_url = "https://homelab.andreibadescu.com"
  visibility   = "public"
  topics       = ["cilium", "flux", "gitops", "grafana", "homelab", "kubernetes", "opentelemetry", "opentofu", "sops", "tailscale", "talos"]

  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = true # Renovate merges small updates once CI passes
  delete_branch_on_merge = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  # `tofu destroy` archives the repository instead of deleting it.
  archive_on_destroy = true
  lifecycle {
    prevent_destroy = true
  }
}

# Dependabot alerts for known vulnerabilities (updates themselves come from Renovate).
resource "github_repository_vulnerability_alerts" "homelab" {
  repository = github_repository.homelab.name
  enabled    = true
}

# CI must pass before a pull request can merge; no force pushes or deletion of main. The owner can
# still push directly (enforce_admins = false).
resource "github_branch_protection" "main" {
  repository_id       = github_repository.homelab.node_id
  pattern             = "main"
  enforce_admins      = false
  allows_force_pushes = false
  allows_deletions    = false

  required_status_checks {
    strict   = false
    contexts = ["check"]
  }
}

# Both existed before they were code; adopt them.
import {
  to = github_repository.homelab
  id = "homelab"
}

import {
  to = github_branch_protection.main
  id = "homelab:main"
}
