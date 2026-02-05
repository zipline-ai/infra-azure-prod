resource "azurerm_virtual_network" "hub_vnet" {
  name                = "${var.customer_name}-zipline-hub-vnet"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "hub_subnet" {
  name                 = "${var.customer_name}-zipline-hub-subnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "postgres" {
  name                 = "${var.customer_name}-zipline-postgres-subnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.4.0/24"]

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "hub_postgres_dns_zone" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.hub_rg.name

  depends_on = [
    azurerm_virtual_network.hub_vnet
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_postgres_dns_link" {
  name                  = "${var.customer_name}-zipline-postgres-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.hub_postgres_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.hub_vnet.id
  resource_group_name   = azurerm_resource_group.hub_rg.name
  depends_on            = [azurerm_subnet.hub_subnet]
}

# Subnet for private endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.customer_name}-zipline-pe-subnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Subnet for Kyuubi cluster
resource "azurerm_subnet" "kyuubi_subnet" {
  name                 = "${var.customer_name}-zipline-kyuubi-subnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.6.0/24"]
}

# Private endpoint for PostgreSQL to allow AKS to connect
resource "azurerm_private_endpoint" "postgres" {
  name                = "${var.customer_name}-zipline-postgres-pe"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.customer_name}-zipline-postgres-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.orchestration_instance.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "postgres-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.hub_postgres_dns_zone.id]
  }
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub_vnet.name
}

output "hub_subnet_name" {
  value = azurerm_subnet.hub_subnet.name
}