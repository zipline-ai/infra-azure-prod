resource "azurerm_storage_container" "zipline_artifacts" {
  name = "${lower(var.customer_name)}-zipline-artifacts"
  storage_account_id = var.azure_storage_account_id
}

output "artifact_prefix" {
  value = "https://${var.azure_storage_account_name}.blob.core.windows.net/${azurerm_storage_container.zipline_artifacts.name}"
}