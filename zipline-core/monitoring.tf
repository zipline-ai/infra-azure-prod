#############################################################
# Monitoring Resources
#############################################################

# Reference existing AKS cluster
data "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

# Azure Monitor Workspace for Managed Prometheus
resource "azurerm_monitor_workspace" "aks" {
  name                = "${var.customer_name}-zipline-prometheus"
  location            = data.azurerm_resource_group.hub_rg.location
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "aks" {
  name                              = "${var.customer_name}-zipline-grafana"
  location                          = data.azurerm_resource_group.hub_rg.location
  resource_group_name               = data.azurerm_resource_group.hub_rg.name
  grafana_major_version             = 11
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.aks.id
  }
}

# Grant Grafana access to read monitoring data
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = data.azurerm_resource_group.hub_rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.aks.identity[0].principal_id
}

# Grant Grafana access to query Azure Monitor Workspace (Prometheus)
resource "azurerm_role_assignment" "grafana_monitor_data_reader" {
  scope                = azurerm_monitor_workspace.aks.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.aks.identity[0].principal_id
}

resource "azurerm_role_assignment" "workload_monitoring_reader" {
  scope                = azurerm_monitor_workspace.aks.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = data.azurerm_user_assigned_identity.workload_identity.principal_id
}

#############################################################
# Prometheus Data Collection
#############################################################

# Link Azure Monitor Workspace to AKS for Managed Prometheus
resource "azurerm_monitor_data_collection_endpoint" "aks" {
  name                = "${var.customer_name}-zipline-dce"
  location            = data.azurerm_resource_group.hub_rg.location
  resource_group_name = data.azurerm_resource_group.hub_rg.name
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "aks_prometheus" {
  name                        = "${var.customer_name}-zipline-prometheus-dcr"
  location                    = data.azurerm_resource_group.hub_rg.location
  resource_group_name         = data.azurerm_resource_group.hub_rg.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks.id

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.aks.id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_prometheus" {
  name                    = "${var.customer_name}-zipline-prometheus-dcra"
  target_resource_id      = data.azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_prometheus.id
}

#############################################################
# Outputs
#############################################################

output "subscription_id" {
  value = var.subscription_id
}

output "monitor_workspace_id" {
  value = azurerm_monitor_workspace.aks.id
}

output "monitor_workspace_name" {
  value = azurerm_monitor_workspace.aks.name
}

output "grafana_endpoint" {
  value = azurerm_dashboard_grafana.aks.endpoint
}