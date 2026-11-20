# Projects ("tenants") whose manifests live in their own repositories (docs/new-project.md). Flux reads
# each one with a read-only deploy key; the private half is in kubernetes/tenants/<project>/.
resource "github_repository_deploy_key" "tenant_enjoydevops" {
  title      = "flux-homelab"
  repository = "enjoydevops"
  key        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXG/wmTpVYv+hK2ip1FUVS/bRI+bc7O15vgTbXEO3AF"
  read_only  = true
}
