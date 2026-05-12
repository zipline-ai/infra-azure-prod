###############################################################################
# Resource group
###############################################################################

import {
  to = azurerm_resource_group.crucible
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
}

resource "azurerm_resource_group" "crucible" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################################
# AKS cluster
###############################################################################

import {
  to = azurerm_kubernetes_cluster.crucible
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerService/managedClusters/${var.cluster_name}"
}

resource "azurerm_kubernetes_cluster" "crucible" {
  name                = var.cluster_name
  location            = azurerm_resource_group.crucible.location
  resource_group_name = azurerm_resource_group.crucible.name
  dns_prefix          = "crucible-a-crucible-rg-3cece9"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "nodepool1"
    vm_size              = "Standard_D4s_v3"
    auto_scaling_enabled = true
    node_count           = 5
    min_count            = 1
    max_count            = 10
    os_sku               = "Ubuntu"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "azure"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    pod_cidr            = "10.244.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  node_os_upgrade_channel           = "NodeImage"
  role_based_access_control_enabled = true

  lifecycle {
    ignore_changes = [
      # Node count drifts via autoscaler.
      default_node_pool[0].node_count,
      # Live kubernetes_version drifts from the variable (auto-patched).
      kubernetes_version,
      # The cluster was created via the portal with an admin SSH key and an
      # auto-generated kubelet identity (MC_* RG). These are immutable / would
      # force replacement; treat them as out-of-band state.
      linux_profile,
      kubelet_identity,
      # Default-pool upgrade settings drift from current portal defaults.
      default_node_pool[0].upgrade_settings,
      node_provisioning_profile,
    ]
  }
}

###############################################################################
# Additional node pools (one per non-default pool on the live cluster)
###############################################################################

# Long-running arm64 worker pool (general crucible workloads on Graviton-class VMs).
import {
  to = azurerm_kubernetes_cluster_node_pool.arm64
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.ContainerService/managedClusters/crucible-aks/agentPools/arm64"
}

resource "azurerm_kubernetes_cluster_node_pool" "arm64" {
  name                  = "arm64"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.crucible.id
  vm_size               = "Standard_D4ps_v6"
  mode                  = "User"
  auto_scaling_enabled  = true
  node_count            = 2
  min_count             = 0
  max_count             = 2
  os_sku                = "Ubuntu"
  node_labels = {
    "crucible.ai/arch" = "arm64"
  }

  lifecycle {
    ignore_changes = [node_count, upgrade_settings]
  }
}

# NVMe-backed pool for shuffle-heavy Spark / large Flink state.
import {
  to = azurerm_kubernetes_cluster_node_pool.nvme
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.ContainerService/managedClusters/crucible-aks/agentPools/nvme"
}

resource "azurerm_kubernetes_cluster_node_pool" "nvme" {
  name                  = "nvme"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.crucible.id
  vm_size               = "Standard_D4plds_v6"
  mode                  = "User"
  auto_scaling_enabled  = true
  node_count            = 0
  min_count             = 0
  max_count             = 3
  os_sku                = "Ubuntu"
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 220
  node_labels = {
    "crucible.ai/nvme" = "true"
  }
  node_taints = [
    "crucible.ai/nvme=true:NoSchedule",
  ]

  lifecycle {
    ignore_changes = [node_count, upgrade_settings]
  }
}

# Spot + NVMe pool — cheapest crucible workload tier.
import {
  to = azurerm_kubernetes_cluster_node_pool.spotnvme
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.ContainerService/managedClusters/crucible-aks/agentPools/spotnvme"
}

resource "azurerm_kubernetes_cluster_node_pool" "spotnvme" {
  name                  = "spotnvme"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.crucible.id
  vm_size               = "Standard_D4plds_v6"
  mode                  = "User"
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  auto_scaling_enabled  = true
  node_count            = 0
  min_count             = 0
  max_count             = 3
  os_sku                = "Ubuntu"
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 220
  node_labels = {
    "crucible.ai/arch"                       = "arm64"
    "crucible.ai/nvme"                       = "true"
    "crucible.ai/spot"                       = "true"
    "kubernetes.azure.com/scalesetpriority"  = "spot"
  }
  node_taints = [
    "crucible.ai/nvme=true:NoSchedule",
    "crucible.ai/spot=true:NoSchedule",
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule",
  ]

  lifecycle {
    ignore_changes = [node_count, upgrade_settings]
  }
}

# Smaller spot pool for lighter workloads.
import {
  to = azurerm_kubernetes_cluster_node_pool.spotnvme2
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.ContainerService/managedClusters/crucible-aks/agentPools/spotnvme2"
}

resource "azurerm_kubernetes_cluster_node_pool" "spotnvme2" {
  name                  = "spotnvme2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.crucible.id
  vm_size               = "Standard_D2plds_v6"
  mode                  = "User"
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  auto_scaling_enabled  = true
  node_count            = 0
  min_count             = 0
  max_count             = 1
  os_sku                = "Ubuntu"
  node_labels = {
    "crucible.ai/arch"                       = "arm64"
    "crucible.ai/nvme"                       = "true"
    "crucible.ai/spot"                       = "true"
    "kubernetes.azure.com/scalesetpriority"  = "spot"
  }
  node_taints = [
    "crucible.ai/nvme=true:NoSchedule",
    "crucible.ai/spot=true:NoSchedule",
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule",
  ]

  lifecycle {
    ignore_changes = [node_count, upgrade_settings]
  }
}
