variable "subscription_id" {
  description = "Azure subscription hosting the Crucible infrastructure."
  type        = string
  default     = "3cece986-9416-439c-98a6-441ff986c88d"
}

variable "location" {
  description = "Azure region for Crucible resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group holding the Crucible AKS cluster, identity, and key vault."
  type        = string
  default     = "crucible-rg"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "crucible-aks"
}

variable "kubernetes_version" {
  description = "Control-plane Kubernetes version (minor; node pools follow)."
  type        = string
  default     = "1.33"
}

variable "spark_identity_name" {
  description = "User-assigned managed identity shared by the Crucible gateway and tenant Spark/Flink workloads."
  type        = string
  default     = "crucible-spark-identity"
}

variable "key_vault_name" {
  description = "Key vault for Crucible secrets."
  type        = string
  default     = "crucible-azure-kv"
}

variable "shared_storage_account_name" {
  description = "Existing storage account that holds the Crucible blob container (managed in zipline-core)."
  type        = string
  default     = "ziplineai2"
}

variable "shared_storage_account_resource_group" {
  description = "RG of the shared storage account."
  type        = string
  default     = "DefaultResourceGroup-WUS2"
}

variable "tenant_namespaces" {
  description = "Tenant namespaces that receive federated credentials for spark-operator-spark + flink SAs."
  type        = set(string)
  default     = ["test-ns-a", "test-ns-b"]
}
