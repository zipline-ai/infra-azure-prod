resource "azurerm_postgresql_flexible_server" "orchestration_instance" {
  name                          = "${var.customer_name}-zipline-orch-instance"
  location                      = azurerm_resource_group.hub_rg.location
  resource_group_name           = azurerm_resource_group.hub_rg.name
  version                       = "16"
  public_network_access_enabled = true
  administrator_login           = "locker_user"
  administrator_password        = random_password.db_password.result

  storage_mb   = 32768
  storage_tier = "P4"
  sku_name     = "GP_Standard_D8ds_v5"

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.hub_postgres_dns_link
  ]
  lifecycle {
    ignore_changes = [
      authentication[0].tenant_id
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

# Allow specific IP addresses to access PostgreSQL
# Add your allowed IP addresses here
resource "azurerm_postgresql_flexible_server_firewall_rule" "allowed_ips" {
  for_each = {
    # List one to set this up
    "Sean" = "184.14.224.39"
  }

  name             = "allow-${each.key}"
  server_id        = azurerm_postgresql_flexible_server.orchestration_instance.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

resource "random_password" "db_password" {
  length  = 16
  special = true
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

# Role assignment already exists for users, not managed by Terraform
# resource "azurerm_role_assignment" "kv_terraform_secrets_officer" {
#   scope                = azurerm_key_vault.main.id
#   role_definition_name = "Key Vault Secrets Officer"
#   principal_id         = data.azurerm_client_config.current.object_id
# }



resource "azurerm_key_vault_secret" "pg_admin_username" {
  name         = "pg-admin-username"
  value        = "locker_user"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "pg_admin_password" {
  name         = "pg-admin-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "pg_hub_url" {
  name         = "pg-hub-url"
  value        = "jdbc:postgresql://${azurerm_postgresql_flexible_server.orchestration_instance.fqdn}:5432/${azurerm_postgresql_flexible_server_database.orchestration_database.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "pg_ui_url" {
  name         = "pg-ui-url"
  value        = "postgres://${azurerm_key_vault_secret.pg_admin_username.value}@${azurerm_postgresql_flexible_server.orchestration_instance.fqdn}:5432/${azurerm_postgresql_flexible_server_database.orchestration_database.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id
}


output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.orchestration_instance.name
}

output "postgres_db_name" {
  value = azurerm_postgresql_flexible_server_database.orchestration_database.name
}

output "keyvault_name" {
  value = azurerm_key_vault.main.name
}