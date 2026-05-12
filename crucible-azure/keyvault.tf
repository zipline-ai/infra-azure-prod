###############################################################################
# Key vault for crucible secrets (RBAC-authorized).
# Grants the spark UAMI Secrets User so workloads can read secrets bound to
# their service account via WI.
###############################################################################

data "azurerm_client_config" "current" {}

import {
  to = azurerm_key_vault.crucible
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
}

resource "azurerm_key_vault" "crucible" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.crucible.location
  resource_group_name        = azurerm_resource_group.crucible.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

import {
  to = azurerm_role_assignment.spark_kv_secrets_user
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.KeyVault/vaults/crucible-azure-kv/providers/Microsoft.Authorization/roleAssignments/b87030ef-0395-4c8c-b426-cce7a49df050"
}

resource "azurerm_role_assignment" "spark_kv_secrets_user" {
  scope                = azurerm_key_vault.crucible.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}
