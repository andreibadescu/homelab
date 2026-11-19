resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_extensions
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
}

locals {
  installer_image = data.talos_image_factory_urls.this.urls.installer_secureboot
}

output "schematic_id" {
  value = talos_image_factory_schematic.this.id
}

output "iso_secureboot_url" {
  description = "SecureBoot ISO for the installer USB stick."
  value       = data.talos_image_factory_urls.this.urls.iso_secureboot
}

output "installer_image" {
  description = "SecureBoot installer image the node installs and upgrades from."
  value       = local.installer_image
}
