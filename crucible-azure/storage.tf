###############################################################################
# Storage container on the shared ziplineai2 account
# (the account itself lives in DefaultResourceGroup-WUS2 and is managed elsewhere;
#  we only own the `crucible` container and the role grants that let workloads
#  read/write it via Workload Identity.)
###############################################################################

data "azurerm_storage_account" "shared" {
  name                = var.shared_storage_account_name
  resource_group_name = var.shared_storage_account_resource_group
}

import {
  to = azurerm_storage_container.crucible
  id = "https://${var.shared_storage_account_name}.blob.core.windows.net/crucible"
}

resource "azurerm_storage_container" "crucible" {
  name                  = "crucible"
  storage_account_id    = data.azurerm_storage_account.shared.id
  container_access_type = "private"
}

###############################################################################
# Role assignments granting the shared spark UAMI access to blob data + RG mgmt.
# (The Owner + Contributor pair on the storage account is the live state from
#  the manual setup. Owner is normally avoided for workloads, but matches what
#  exists today; revisit in a follow-up that tightens to Contributor only.)
###############################################################################

import {
  to = azurerm_role_assignment.spark_blob_contributor
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/DefaultResourceGroup-WUS2/providers/Microsoft.Storage/storageAccounts/ziplineai2/providers/Microsoft.Authorization/roleAssignments/3f410ab7-ffab-45d5-8c5a-3c32e15cba58"
}

resource "azurerm_role_assignment" "spark_blob_contributor" {
  scope                = data.azurerm_storage_account.shared.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}

import {
  to = azurerm_role_assignment.spark_blob_owner
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/DefaultResourceGroup-WUS2/providers/Microsoft.Storage/storageAccounts/ziplineai2/providers/Microsoft.Authorization/roleAssignments/a88280f4-f7aa-4238-abb3-cd45239257c9"
}

resource "azurerm_role_assignment" "spark_blob_owner" {
  scope                = data.azurerm_storage_account.shared.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}

# Required so the gateway can create namespace SAs, bind federated credentials,
# and update labels/annotations on managed identities.
import {
  to = azurerm_role_assignment.spark_managed_identity_contributor
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.Authorization/roleAssignments/fe4bc203-33c7-4264-a6c5-7e9fd015d6db"
}

resource "azurerm_role_assignment" "spark_managed_identity_contributor" {
  scope                = azurerm_resource_group.crucible.id
  role_definition_name = "Managed Identity Contributor"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}

import {
  to = azurerm_role_assignment.spark_user_access_admin
  id = "/subscriptions/3cece986-9416-439c-98a6-441ff986c88d/resourceGroups/crucible-rg/providers/Microsoft.Authorization/roleAssignments/ef87b4ee-3ac1-4e6c-97f3-2958fabf3246"
}

resource "azurerm_role_assignment" "spark_user_access_admin" {
  scope                = azurerm_resource_group.crucible.id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}
