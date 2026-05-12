###############################################################################
# Outputs — consumed by the platform CI workflows (crucible integration tests)
# and by anyone running `helm install crucible ./helm/crucible -f values-aks-dev.yaml`.
###############################################################################

output "resource_group" {
  description = "Crucible resource group name."
  value       = azurerm_resource_group.crucible.name
}

output "aks_cluster_name" {
  description = "AKS cluster name (use with `az aks get-credentials`)."
  value       = azurerm_kubernetes_cluster.crucible.name
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL. Plug into helm/crucible/values-aks-dev.yaml namespaceOnboarding.aksOIDCIssuer and into platform's federated SP subject."
  value       = azurerm_kubernetes_cluster.crucible.oidc_issuer_url
}

output "spark_identity_client_id" {
  description = "UAMI client-id used as `azure.workload.identity/client-id` on Crucible SAs."
  value       = azurerm_user_assigned_identity.spark.client_id
}

output "spark_identity_principal_id" {
  description = "UAMI principal-id (for additional role grants)."
  value       = azurerm_user_assigned_identity.spark.principal_id
}

output "storage_container_url" {
  description = "abfss URL of the crucible blob container."
  value       = "abfss://${azurerm_storage_container.crucible.name}@${data.azurerm_storage_account.shared.name}.dfs.core.windows.net"
}

output "key_vault_name" {
  description = "Crucible key vault name."
  value       = azurerm_key_vault.crucible.name
}
