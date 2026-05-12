###############################################################################
# Shared user-assigned managed identity
#
# A single UAMI is federated to multiple K8s service accounts (the Crucible
# gateway in crucible-system + the spark/flink SAs in each tenant namespace).
# This matches the GCP setup where `crucible-spark@crucible-io.iam.gserviceaccount.com`
# is bound to both `test-ns-*/spark-operator-spark` and `test-ns-*/flink` via
# workload identity. (GCP also has a separate `crucible-gateway` SA; on Azure
# we collapse to one UAMI since the permission surfaces are identical.)
###############################################################################

import {
  to = azurerm_user_assigned_identity.spark
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}"
}

resource "azurerm_user_assigned_identity" "spark" {
  name                = var.spark_identity_name
  location            = azurerm_resource_group.crucible.location
  resource_group_name = azurerm_resource_group.crucible.name
}

###############################################################################
# Federated credentials — Crucible system + tenant namespaces
#
# claims-demo-hub federations live on the live UAMI as well but are application-
# specific demo bindings; managing them here would couple this module to that
# demo. They remain unmanaged for now and can be imported separately if needed.
###############################################################################

# Gateway pod (one per cluster).
import {
  to = azurerm_federated_identity_credential.gateway
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}/federatedIdentityCredentials/crucible-gateway-sa-federation"
}

resource "azurerm_federated_identity_credential" "gateway" {
  name                = "crucible-gateway-sa-federation"
  user_assigned_identity_id = azurerm_user_assigned_identity.spark.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
  subject             = "system:serviceaccount:crucible-system:crucible"
}

# test-ns-a — Spark + Flink SAs.
import {
  to = azurerm_federated_identity_credential.spark_test_ns_a
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}/federatedIdentityCredentials/crucible-spark-sa-federation"
}

resource "azurerm_federated_identity_credential" "spark_test_ns_a" {
  name                = "crucible-spark-sa-federation"
  user_assigned_identity_id = azurerm_user_assigned_identity.spark.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
  subject             = "system:serviceaccount:test-ns-a:spark-operator-spark"
}

import {
  to = azurerm_federated_identity_credential.flink_test_ns_a
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}/federatedIdentityCredentials/crucible-flink-sa-federation"
}

resource "azurerm_federated_identity_credential" "flink_test_ns_a" {
  name                = "crucible-flink-sa-federation"
  user_assigned_identity_id = azurerm_user_assigned_identity.spark.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
  subject             = "system:serviceaccount:test-ns-a:flink"
}

# test-ns-b — Spark + Flink SAs.
import {
  to = azurerm_federated_identity_credential.spark_test_ns_b
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}/federatedIdentityCredentials/crucible-spark-sa-test-ns-b"
}

resource "azurerm_federated_identity_credential" "spark_test_ns_b" {
  name                = "crucible-spark-sa-test-ns-b"
  user_assigned_identity_id = azurerm_user_assigned_identity.spark.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
  subject             = "system:serviceaccount:test-ns-b:spark-operator-spark"
}

import {
  to = azurerm_federated_identity_credential.flink_test_ns_b
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${var.spark_identity_name}/federatedIdentityCredentials/crucible-flink-sa-test-ns-b"
}

resource "azurerm_federated_identity_credential" "flink_test_ns_b" {
  name                = "crucible-flink-sa-test-ns-b"
  user_assigned_identity_id = azurerm_user_assigned_identity.spark.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
  subject             = "system:serviceaccount:test-ns-b:flink"
}
