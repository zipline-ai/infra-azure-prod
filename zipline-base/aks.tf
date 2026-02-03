resource "azurerm_resource_group" "hub_rg" {
  location = var.location
  name     = "${var.customer_name}-zipline-rg"
}

resource "azurerm_kubernetes_cluster" "hub_cluster" {
  location            = var.location
  name                = "${var.customer_name}-zipline-aks"
  resource_group_name = azurerm_resource_group.hub_rg.name
  dns_prefix          = "orchestration"

  default_node_pool {
    name           = "default"
    node_count     = 3
    vm_size        = "Standard_D8s_v6"
    vnet_subnet_id = azurerm_subnet.hub_subnet.id
    temporary_name_for_rotation = "defaulttmp"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.3.10"
    service_cidr   = "10.0.3.0/24"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  monitor_metrics {
    annotations_allowed = "*"
    labels_allowed      = "*"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks.id
    msi_auth_for_monitoring_enabled = true
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
      oms_agent,
    ]
  }
}

#############################################################
# Monitoring Resources
#############################################################

# Log Analytics Workspace for Container Insights
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.customer_name}-zipline-logs"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_role_assignment" "aks_monitoring_publisher" {
  scope                = azurerm_log_analytics_workspace.aks.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.hub_cluster.identity[0].principal_id
}

resource "azurerm_role_assignment" "workload_logs_reader" {
  scope                = azurerm_log_analytics_workspace.aks.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
#############################################################

# User Assigned Managed Identity for workload
resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.customer_name}-zipline-workload-identity"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
}

# Federated Identity Credential
resource "azurerm_federated_identity_credential" "workload" {
  name                = "${var.customer_name}-zipline-federated-credential"
  resource_group_name = azurerm_resource_group.hub_rg.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.hub_cluster.oidc_issuer_url
  subject             = "system:serviceaccount:zipline-system:orchestration-sa"
}

resource "azurerm_role_assignment" "workload_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "workload_storage_contributor" {
  scope                = var.azure_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "aks_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.hub_cluster.key_vault_secrets_provider[0].secret_identity[0].object_id
}

#############################################################

output "resource_group" {
  value = azurerm_resource_group.hub_rg.name
}

output "aks_host" {
  value = azurerm_kubernetes_cluster.hub_cluster.kube_config.0.host
  sensitive = true
}

output "aks_client_certificate" {
  value = azurerm_kubernetes_cluster.hub_cluster.kube_config.0.client_certificate
  sensitive = true
}

output "aks_client_key" {
  value = azurerm_kubernetes_cluster.hub_cluster.kube_config.0.client_key
  sensitive = true
}

output "aks_cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.hub_cluster.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "aks_node_resource_group" {
  value = azurerm_kubernetes_cluster.hub_cluster.node_resource_group
}

output "workload_identity_name" {
  value = azurerm_user_assigned_identity.workload.name
}

output "keyvault_identity_client_id" {
  value = azurerm_kubernetes_cluster.hub_cluster.key_vault_secrets_provider[0].secret_identity[0].client_id
  sensitive = true
}

output "subscription_id" {
  value = var.subscription_id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.aks.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.aks.name
}

output "log_analytics_workspace_workspace_id" {
  value = azurerm_log_analytics_workspace.aks.workspace_id
}

#############################################################
# Kyuubi Cluster (separate from hub cluster)
#############################################################

resource "azurerm_kubernetes_cluster" "kyuubi_cluster" {
  location            = var.location
  name                = "${var.customer_name}-kyuubi-aks"
  resource_group_name = azurerm_resource_group.hub_rg.name
  dns_prefix          = "kyuubi"

  default_node_pool {
    name                        = "default"
    node_count                  = 3
    vm_size                     = "Standard_D8s_v6"
    vnet_subnet_id              = azurerm_subnet.kyuubi_subnet.id
    temporary_name_for_rotation = "defaulttmp"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.7.10"
    service_cidr   = "10.0.7.0/24"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  monitor_metrics {
    annotations_allowed = "*"
    labels_allowed      = "*"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.kyuubi.id
    msi_auth_for_monitoring_enabled = true
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
      oms_agent,
    ]
  }
}

# Log Analytics Workspace for Kyuubi cluster
resource "azurerm_log_analytics_workspace" "kyuubi" {
  name                = "${var.customer_name}-kyuubi-logs"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_role_assignment" "kyuubi_monitoring_publisher" {
  scope                = azurerm_log_analytics_workspace.kyuubi.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.kyuubi_cluster.identity[0].principal_id
}

resource "azurerm_role_assignment" "kyuubi_aks_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.kyuubi_cluster.key_vault_secrets_provider[0].secret_identity[0].object_id
}

# User Assigned Managed Identity for Kyuubi workload
resource "azurerm_user_assigned_identity" "kyuubi_workload" {
  name                = "kyuubi-workload-identity"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
}

# Federated Identity Credential for Kyuubi service account (uses kyuubi_cluster OIDC issuer)
resource "azurerm_federated_identity_credential" "kyuubi_workload" {
  name                = "kyuubi-federated-credential"
  resource_group_name = azurerm_resource_group.hub_rg.name
  parent_id           = azurerm_user_assigned_identity.kyuubi_workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.kyuubi_cluster.oidc_issuer_url
  subject             = "system:serviceaccount:kyuubi:kyuubi"
}

# Grant Kyuubi identity access to storage
# Using Storage Blob Data Owner (not Contributor) to allow ACL operations for Spark event logs
resource "azurerm_role_assignment" "kyuubi_storage_contributor" {
  scope                = var.azure_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.kyuubi_workload.principal_id
}

#############################################################
# Kyuubi Cluster Outputs
#############################################################

output "kyuubi_aks_host" {
  value     = azurerm_kubernetes_cluster.kyuubi_cluster.kube_config.0.host
  sensitive = true
}

output "kyuubi_aks_client_certificate" {
  value     = azurerm_kubernetes_cluster.kyuubi_cluster.kube_config.0.client_certificate
  sensitive = true
}

output "kyuubi_aks_client_key" {
  value     = azurerm_kubernetes_cluster.kyuubi_cluster.kube_config.0.client_key
  sensitive = true
}

output "kyuubi_aks_cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.kyuubi_cluster.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "kyuubi_aks_node_resource_group" {
  value = azurerm_kubernetes_cluster.kyuubi_cluster.node_resource_group
}

output "kyuubi_log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.kyuubi.id
}

output "kyuubi_log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.kyuubi.name
}

output "kyuubi_internal_port" {
  description = "Kyuubi Thrift Binary port"
  value       = 10009
}

output "kyuubi_workload_identity_client_id" {
  description = "Client ID for Kyuubi workload identity"
  value       = azurerm_user_assigned_identity.kyuubi_workload.client_id
}
