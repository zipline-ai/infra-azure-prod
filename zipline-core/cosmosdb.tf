# Data sources to reference existing base-azure resources
data "azurerm_resource_group" "hub_rg" {
  name = var.aks_resource_group
}

data "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

data "azurerm_subnet" "hub_subnet" {
  name                 = var.hub_subnet_name
  virtual_network_name = data.azurerm_virtual_network.hub_vnet.name
  resource_group_name  = data.azurerm_resource_group.hub_rg.name
}

data "azurerm_key_vault" "main" {
  name                = var.keyvault_name
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

# Cosmos DB Resources
resource "azurerm_resource_group" "cosmos_rg" {
  location = var.cosmos_location
  name     = "${var.customer_name}-zipline-cosmos-rg"
}

resource "azurerm_cosmosdb_account" "zipline_instance" {
  name                = "zipline-${lower(var.customer_name)}-instance"
  location            = azurerm_resource_group.cosmos_rg.location
  resource_group_name = azurerm_resource_group.cosmos_rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Production workload settings
  capacity {
    total_throughput_limit = var.cosmos_total_throughput_limit
  }

  # Availability zone redundancy
  automatic_failover_enabled       = true
  multiple_write_locations_enabled = false
  public_network_access_enabled    = false
  network_acl_bypass_for_azure_services = false

  consistency_policy {
    consistency_level = "Eventual"
  }

  geo_location {
    location          = azurerm_resource_group.cosmos_rg.location
    failover_priority = 0
    zone_redundant    = var.cosmos_zone_redundant
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = 8
    storage_redundancy  = "Geo"
  }
}

# SQL Database with autoscale
resource "azurerm_cosmosdb_sql_database" "chronon" {
  name                = "chronon"
  resource_group_name = azurerm_resource_group.cosmos_rg.name
  account_name        = azurerm_cosmosdb_account.zipline_instance.name

  autoscale_settings {
    max_throughput = var.cosmos_total_throughput_limit
  }
}

# Private DNS Zone for Cosmos DB
resource "azurerm_private_dns_zone" "cosmos_dns_zone" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

# Link private DNS zone to hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_dns_link" {
  name                  = "${var.customer_name}-zipline-cosmos-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  resource_group_name   = data.azurerm_resource_group.hub_rg.name
}

# Private endpoint for Cosmos DB
resource "azurerm_private_endpoint" "cosmos_endpoint" {
  name                = "${var.customer_name}-zipline-cosmos-endpoint"
  location            = data.azurerm_resource_group.hub_rg.location
  resource_group_name = data.azurerm_resource_group.hub_rg.name
  subnet_id           = data.azurerm_subnet.hub_subnet.id

  private_service_connection {
    name                           = "${var.customer_name}-zipline-cosmos-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.zipline_instance.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmos_dns_zone.id]
  }
}

# Containers - Batch Tables (multi-level partition: /dataset and /keyHash)
resource "azurerm_cosmosdb_sql_container" "groupby_batch" {
  name                  = "groupby_batch"
  resource_group_name   = azurerm_resource_group.cosmos_rg.name
  account_name          = azurerm_cosmosdb_account.zipline_instance.name
  database_name         = azurerm_cosmosdb_sql_database.chronon.name
  partition_key_paths   = ["/dataset", "/keyHash"]
  partition_key_kind    = "MultiHash"
  partition_key_version = 2
  default_ttl           = 432000 # 120h = 5 days in seconds
}

# Containers - Streaming Tables (multi-level partition: /dataset and /keyHashDay)
resource "azurerm_cosmosdb_sql_container" "groupby_streaming" {
  name                  = "groupby_streaming"
  resource_group_name   = azurerm_resource_group.cosmos_rg.name
  account_name          = azurerm_cosmosdb_account.zipline_instance.name
  database_name         = azurerm_cosmosdb_sql_database.chronon.name
  partition_key_paths   = ["/dataset", "/keyHashDay"]
  partition_key_kind    = "MultiHash"
  partition_key_version = 2
  default_ttl           = 432000
}

# Containers - Metadata Tables (single partition: /keyHash)
resource "azurerm_cosmosdb_sql_container" "chronon_metadata" {
  name                = "chronon_metadata"
  resource_group_name = azurerm_resource_group.cosmos_rg.name
  account_name        = azurerm_cosmosdb_account.zipline_instance.name
  database_name       = azurerm_cosmosdb_sql_database.chronon.name
  partition_key_paths = ["/keyHash"]
  partition_key_version = 2
  default_ttl         = 432000
}

resource "azurerm_cosmosdb_sql_container" "table_partitions" {
  name                = "table_partitions"
  resource_group_name = azurerm_resource_group.cosmos_rg.name
  account_name        = azurerm_cosmosdb_account.zipline_instance.name
  database_name       = azurerm_cosmosdb_sql_database.chronon.name
  partition_key_paths = ["/keyHash"]
  partition_key_version = 2
  default_ttl         = 432000
}

# Store Cosmos DB key in Key Vault
resource "azurerm_key_vault_secret" "cosmos_primary_key" {
  name         = "cosmos-primary-key"
  value        = azurerm_cosmosdb_account.zipline_instance.primary_key
  key_vault_id = data.azurerm_key_vault.main.id
}
