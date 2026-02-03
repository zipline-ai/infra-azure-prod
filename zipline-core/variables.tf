# General Configuration

variable "customer_name" {
  description = "Your Unique Zipline Account Name"
}
variable "zipline_version" {
  description = "Which version of the Zipline Hub to use"
}
variable "docker_token" {
  description = "A token for pulling the private images from Docker. Someone from Zipline should provide this to you"
  sensitive = true
}
variable "location" {
  description = "The Azure location to deploy to"
}

variable "subscription_id" {
  description = "The Azure subscription to use"
}

# Azure Storage Configuration

variable "azure_storage_account_name" {
  description = "The Azure storage account to use"
}

variable "azure_storage_account_key" {
  description = "The Azure storage account key to use"
  sensitive = true
}

variable "storage_account_resource_group" {
  description = "The resource group where the storage account is setup"
}

# Cosmos DB Configuration

variable "cosmos_total_throughput_limit" {
  description = "Total throughput limit for Cosmos DB account"
  type        = number
  default     = 1000
}

variable "cosmos_location" {
  description = "Azure region for Cosmos DB deployment"
  type        = string
}

variable "cosmos_zone_redundant" {
  description = "Enable zone redundancy for Cosmos DB (requires region support and capacity)"
  type        = bool
  default     = false
}

# AKS Configuration

variable "aks_resource_group" {
  description = "The resource group the aks has been setup in"
  type        = string
}

variable "aks_cluster_name" {
  description = "The name of the aks cluster"
}

variable "aks_host" {
  description = "The host of the aks cluster"
}

variable "aks_client_certificate" {
  description = "The client certificate for the aks cluster"
  sensitive = true
}

variable "aks_client_key" {
  description = "The client key for the aks cluster"
  sensitive = true
}

variable "aks_cluster_ca_certificate" {
  description = "The cluster CA certificate for the aks cluster"
  sensitive = true
}

variable "aks_node_resource_group" {
  description = "The resource group for the aks nodes"
}

# Database Configuration

variable "postgres_db_name" {
  description = "The name of the postgres database"
  default = "execution_info"
}

variable "postgres_fqdn" {
  description = "The fqdn of the postgres database"
}

# Identity and Security

variable "workload_identity_name" {
  description = "The workload identity name for the aks cluster"
}

variable "keyvault_name" {
  description = "The name of the keyvault"
}

variable "keyvault_identity_client_id" {
  description = "The keyvault identity client id"
}

# Kyuubi Service Configuration

variable "kyuubi_host" {
  description = "The host of the kyuubi cluster"
}

variable "kyuubi_port" {
  description = "The port of the kyuubi cluster"
  default = 10099
}

# Domain Configuration

variable "hub_domain" {
  description = "The domain to use for initializing the Zipline Hub. This should be a domain you can set DNS records for."
}

variable "ui_domain" {
  description = "The domain to use for initializing the Zipline UI. This should be a domain you can set DNS records for."
}


variable "admin_email" {
  description = "Email for receiving certificate updates"
}

# Authentication and Access

variable "enable_oauth" {
  description = "Whether to use oauth to authenticate access to the Zipline Hub"
  default = true
}

variable "oauth_client_id" {
  description = "Optional: Existing OAuth2 Client ID. If empty, a new App Registration will be created."
  type        = string
  default     = ""
}

variable "oauth_client_secret" {
  description = "Optional: Existing OAuth2 Client Secret. Required if oauth_client_id is set."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_provider" {
  description = "The OAuth2 Provider to use (e.g., 'azure', 'google'). Defaults to 'azure'."
  type        = string
  default     = "azure"
}

variable "email_domains" {
  description = "List of allowed email domains for OAuth2 Proxy. Use ['*'] to allow any domain."
  type        = list(string)
  default     = ["*"]
}

# Kyuubi cluster configuration. These are only needed if kyuubi host is left empty
variable "kyuubi_aks_host" {
  description = "The host of the aks cluster for kyuubi"
  default = ""
}

variable "kyuubi_aks_client_certificate" {
  description = "The client certificate for the aks cluster for kyuubi"
  default = ""
  sensitive = true
}

variable "kyuubi_aks_client_key" {
  description = "The client key for the aks cluster for kyuubi"
  default = ""
  sensitive = true
}

variable "kyuubi_aks_cluster_ca_certificate" {
  description = "The cluster CA certificate for the aks cluster for kyuubi"
  default = ""
  sensitive = true
}

variable "kyuubi_workload_identity_client_id" {
  description = "The workload identity client id for kyuubi"
  default = ""
}

# Logs Analytics Configuration
variable "log_analytics_workspace_workspace_id" {
  description = "The workspace id for the log analytics workspace to save logs"
}