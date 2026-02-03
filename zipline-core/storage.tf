data "azurerm_storage_account" "main" {
  name = var.azure_storage_account_name
  resource_group_name = var.storage_account_resource_group
}

resource "azurerm_storage_container" "zipline_artifacts" {
  name = "${lower(var.customer_name)}-zipline-artifacts"
  storage_account_id = data.azurerm_storage_account.main.id
}

output "artifact_prefix" {
  value = "https://${var.azure_storage_account_name}.blob.core.windows.net/${azurerm_storage_container.zipline_artifacts.name}"
}