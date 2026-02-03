resource "azurerm_postgresql_flexible_server" "orchestration_instance" {
  name                          = "${var.customer_name}-zipline-orch-instance"
  location                      = azurerm_resource_group.hub_rg.location
  resource_group_name           = azurerm_resource_group.hub_rg.name
  version                       = "16"
  public_network_access_enabled = true

  storage_mb   = 32768
  storage_tier = "P4"
  sku_name     = "GP_Standard_D8ds_v5"

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.hub_postgres_dns_link
  ]
  lifecycle {
    ignore_changes = [
      authentication[0].tenant_id,
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "orchestration_database" {
  name      = "execution_info"
  server_id = azurerm_postgresql_flexible_server.orchestration_instance.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Add Managed Identity as PostgreSQL AD Admin
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "workload_identity_admin" {
  server_name         = azurerm_postgresql_flexible_server.orchestration_instance.name
  resource_group_name = azurerm_resource_group.hub_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.workload.principal_id
  principal_name      = azurerm_user_assigned_identity.workload.name
  principal_type      = "ServicePrincipal"
}

# Allow AKS subnet to access PostgreSQL
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  name             = "allow-aks-subnet"
  server_id        = azurerm_postgresql_flexible_server.orchestration_instance.id
  start_ip_address = cidrhost(azurerm_subnet.hub_subnet.address_prefixes[0], 0)
  end_ip_address   = cidrhost(azurerm_subnet.hub_subnet.address_prefixes[0], -1)
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "${var.customer_name}-zipline-secrets"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled  = false
}

resource "azurerm_role_assignment" "kv_terraform_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.orchestration_instance.name
}

output "postgres_db_name" {
  value = azurerm_postgresql_flexible_server_database.orchestration_database.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.orchestration_instance.fqdn
}

output "keyvault_name" {
  value = azurerm_key_vault.main.name
}