# General Configuration

variable "customer_name" {
  description = "Your Unique Zipline Account Name"
}
variable "zipline_version" {
  description = "Which version of the Zipline Hub to use"
}
variable "docker_token" {
  description = "A token for pulling the private images from Docker. Someone from Zipline should provide this to you"
  sensitive   = true
}
variable "location" {
  description = "The Azure location to deploy to"
}

variable "subscription_id" {
  description = "The Azure subscription to use"
}

variable "deploy_fetcher" {
  description = "Whether or not to deploy the fetcher service"
  default     = false
}

variable "fetcher_replicas" {
  type        = number
  description = "Number of fetcher replicas"
  default     = 3

  validation {
    condition     = var.fetcher_replicas >= 0 && floor(var.fetcher_replicas) == var.fetcher_replicas
    error_message = "fetcher_replicas must be a non-negative whole number."
  }
}

# Azure Storage Configuration

variable "azure_storage_account_name" {
  description = "The Azure storage account to use"
}

variable "azure_storage_account_key" {
  description = "The Azure storage account key to use"
  sensitive   = true
}

variable "storage_account_resource_group" {
  description = "The resource group where the storage account is setup"
}

variable "warehouse_container_name" {
  description = "The name of the Azure storage container for storing file"
  default     = "warehouse"
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

variable "cosmos_rg" {
  description = "Optional: Cosmos DB resource group if you already have one setup"
  type        = string
  default     = ""
}

variable "cosmos_account" {
  description = "Optional: Cosmos DB account name if you already have one setup"
  type        = string
  default     = ""
}

variable "cosmos_database" {
  description = "Optional: Cosmos DB database name if you already have one setup"
  type        = string
  default     = ""
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
  sensitive   = true
}

variable "aks_client_key" {
  description = "The client key for the aks cluster"
  sensitive   = true
}

variable "aks_cluster_ca_certificate" {
  description = "The cluster CA certificate for the aks cluster"
  sensitive   = true
}

variable "aks_node_resource_group" {
  description = "The resource group for the aks nodes"
}

# Database Configuration

variable "postgres_db_name" {
  description = "The name of the postgres database"
  default     = "execution_info"
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

# Networking

variable "hub_vnet_name" {
  description = "The name of the hub vnet"
}

variable "hub_subnet_name" {
  description = "The name of the hub subnet"
}


# Kyuubi Service Configuration

variable "kyuubi_host" {
  description = "The host of the kyuubi cluster"
}

variable "kyuubi_port" {
  description = "The port of the kyuubi cluster"
  default     = 10099
}

variable "enable_kyuubi_auth" {
  description = "Whether to enable kyuubi authentication. If enabled, kyuubi_username_secret and kyuubi_password_secret must be set in the provided keyvault"
  default     = false
}

variable "kyuubi_username_secret" {
  description = "The name of the secret in the keyvault holding the kyuubi username"
  default     = ""
}


variable "kyuubi_password_secret" {
  description = "The name of the secret in the keyvault holding the kyuubi password"
  default     = ""
}


variable "spark_history_server_url" {
  description = "The url of the spark history server"
}

# Domain Configuration

variable "hub_domain" {
  description = "The domain to use for initializing the Zipline Hub. This should be a domain you can set DNS records for."
}

variable "ui_domain" {
  description = "The domain to use for initializing the Zipline UI. This should be a domain you can set DNS records for."
}

variable "eval_domain" {
  description = "The domain to use for the Zipline Eval service. This should be a domain you can set DNS records for."
}

variable "admin_email" {
  description = "Email for receiving certificate updates"
}

# Authentication and Access

variable "enable_oauth" {
  description = "Whether to use oauth to authenticate access to the Zipline Hub"
  default     = true
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

variable "oauth_scope" {
  description = "Optional: Existing OAuth2 Scope. Required if oauth_client_id is set. Do not include the suffix '/.default' here."
  type        = string
  default     = ""
}

# If you set enable_oauth = true while leaving oauth_client_id and oauth_client_secret blank, an AD Application will be
# created and used to restrict users. In this case set oauth_user_group to the Azure group you would like to allow
# access.
variable "oauth_users_group" {
  description = "Optional: Will grant access to this group to the zipline service. Use the display name"
  type        = string
  default     = ""
}

variable "email_domains" {
  description = "List of allowed email domains for OAuth2 Proxy. Use ['*'] to allow any domain."
  type        = list(string)
  default     = ["*"]
}

# Kyuubi cluster configuration. These are only needed if kyuubi host is left empty
variable "kyuubi_aks_host" {
  description = "The host of the aks cluster for kyuubi"
  default     = ""
}

variable "kyuubi_aks_client_certificate" {
  description = "The client certificate for the aks cluster for kyuubi"
  default     = ""
  sensitive   = true
}

variable "kyuubi_aks_client_key" {
  description = "The client key for the aks cluster for kyuubi"
  default     = ""
  sensitive   = true
}

variable "kyuubi_aks_cluster_ca_certificate" {
  description = "The cluster CA certificate for the aks cluster for kyuubi"
  default     = ""
  sensitive   = true
}

variable "kyuubi_workload_identity_client_id" {
  description = "The workload identity client id for kyuubi"
  default     = ""
}

# Logs Analytics Configuration
variable "log_analytics_workspace_workspace_id" {
  description = "The workspace id for the log analytics workspace to save logs"
}

variable "loki_endpoint" {
  description = "If you need to route logs through a different service, provide the loki endpoint for querying logs"
  default     = ""
}

variable "prometheus_endpoint" {
  description = "If you need to route metrics through a different service, provide the prometheus endpoint for querying metrics"
  default     = ""
}

variable "grafana_endpoint" {
  description = "If you need to route metrics through a different service, provide the grafana endpoint for generating links to metrics"
  default     = ""
}

# Zipline Authentication
variable "zipline_auth_enabled" {
  type        = bool
  description = "Enable Zipline authentication"
  default     = false
}

variable "google_oauth_client_id" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "github_oauth_client_id" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
}

variable "github_oauth_client_secret" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "microsoft_entra_tenant_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}

variable "microsoft_entra_oauth_client_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}


variable "microsoft_entra_oauth_client_secret" {
  type        = string
  description = "Optional for use microsoft Entra ID with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "sso_provider_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_domain" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_issuer" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_secret" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "idp_role_mapping" {
  type        = string
  description = "Optional comma separated list of role mappings for zipline authentication"
  default     = ""
}

variable "idp_group_claim" {
  type        = string
  description = "Optional group claims configured for zipline authentication"
  default     = ""
}

variable "hub_external_url" {
  type        = string
  description = "Override HUB_BASE_URL directly (e.g., http://my-hub-1.2.3.4). Use when a custom proxy sits in front of the nginx LB and hub_domain is not set."
  default     = ""
}

# Flink Configuration

variable "flink_workload_identity_client_id" {
  description = "Client ID of the Flink managed identity (from zipline-base output)"
  type        = string
  default     = ""
}

variable "flink_aks_service_account" {
  description = "Kubernetes service account name for Flink job pods"
  type        = string
  default     = "zipline-flink-sa"
}

variable "flink_aks_namespace" {
  description = "Kubernetes namespace for Flink jobs"
  type        = string
  default     = "zipline-flink"
}

variable "flink_image" {
  description = "Custom Flink Docker image. Defaults to ziplineai/flink:1.20.3"
  type        = string
  default     = "ziplineai/flink:1.20.3"
}