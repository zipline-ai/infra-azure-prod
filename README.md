# infra-azure-prod
# Azure Infrastructure Setup

This repository contains Terraform configurations for setting up Azure infrastructure in two stages: base infrastructure and Zipline core environment.

## Prerequisites

1. Azure CLI installed and configured
2. Terraform or OpenTofu installed
3. Access to an Azure subscription with required permissions

## 1. Base Infrastructure Setup (Optional)

The base infrastructure setup creates fundamental Azure resources. You can skip this if you already have these resources.

### 1.0 Backend Configuration (Optional)

To store the Terraform state remotely in Azure Storage (recommended for team environments):

1. Create an Azure Storage Account and container (if not already existing):
```bash
# Set your variables
RESOURCE_GROUP="your-resource-group"
STORAGE_ACCOUNT_NAME="your-storage-account"
CONTAINER_NAME="terraform-state"
LOCATION="your-azure-region"

# Create resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS

# Create container
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME
```

2. Uncomment and update the backend configuration in : `providers.tf`
```terraform
terraform {
  backend "azurerm" {
    resource_group_name  = "your-resource-group"
    storage_account_name = "your-storage-account"
    container_name      = "terraform-state"
    key                 = "terraform.tfstate"
  }
}
```
3. Initialize Terraform with the backend configuration:
```bash
terraform init
```

### 1.1 Configure Base Variables

Open `zipline-base/variables.tf` and fill in these values:
```terraform
variable "customer_name" { default = "your-prefix" }  
variable "location" { default = "your-region" } # Example: "westus"  
variable "subscription_id" { default = "your-subscription-id" } # Get this from: az account show --query id -o tsv 

```

### 1.2 Apply Base Infrastructure
```bash
cd zipline-base  
terraform init  
terraform plan  
terraform apply
```

## 2. Zipline Core Setup

### 2.0 Backend Configuration (Optional)

To store the Terraform state remotely in Azure Storage (recommended for team environments):

1. Create an Azure Storage Account and container (if not already existing):
```bash
# Set your variables
RESOURCE_GROUP="your-resource-group"
STORAGE_ACCOUNT_NAME="your-storage-account"
CONTAINER_NAME="terraform-state"
LOCATION="your-azure-region"

# Create resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS

# Create container
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME
```

2. Uncomment and update the backend configuration in : `providers.tf`
```terraform
terraform {
  backend "azurerm" {
    resource_group_name  = "your-resource-group"
    storage_account_name = "your-storage-account"
    container_name      = "terraform-state"
    key                 = "terraform.tfstate"
  }
}
```
3. Initialize Terraform with the backend configuration:
```bash
terraform init
```

### 2.1 Get Required Values

If you applied the base infrastructure, get the output values. Otherwise, use these Azure CLI commands to get the required values:

```bash
# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# Get Storage Account details
STORAGE_ACCOUNT_NAME=(az storage account list --query "[0].name" -o tsv) STORAGE_ACCOUNT_ID=(az storage account list --query "[0].id" -o tsv)

# Get AKS details
RESOURCE_GROUP="your-resource-group" CLUSTER_NAME="your-cluster-name"
# Get AKS credentials and details
az aks get-credentials --resource-group RESOURCE_GROUP --nameCLUSTER_NAME
# Get AKS host
AKS_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
# Get AKS client certificate (base64 encoded)
AKS_CLIENT_CERT=$(kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}')
# Get AKS client key (base64 encoded)
AKS_CLIENT_KEY=$(kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}')
# Get AKS CA certificate (base64 encoded)
AKS_CA_CERT=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
# Get AKS node resource group
NODE_RG=(az aks show --resource-groupRESOURCE_GROUP --name $CLUSTER_NAME --query nodeResourceGroup -o tsv)
```
### 2.2 Configure Zipline Core Variables

Update `zipline-core/variables.tf` with the values obtained above:
```terraform
```terraform
# General Configuration
variable "customer_name" {
description = "Prefix used for resource naming"
default = "<YOUR_UNIQUE_NAME>"
}
        
variable "zipline_version" {
description = "Version tag for Zipline hub components"
default = "latest"
}
        
variable "docker_token" {
description = "A token for pulling the private images from Docker. Someone from Zipline should provide this to you"
default = "<DOCKER_TOKEN>"
}

variable "location" {
description = "Azure region for resource deployment"
default = "<LOCATION>"
}

variable "subscription_id" {
description = "The Azure subscription to use"
default = "<SUBSCRIPTION_ID>"
}

# Azure Storage Configuration
variable "azure_storage_account_name" {
description = "Name of the Azure Storage Account"
default = "<STORAGE_ACCOUNT_NAME>"
}

variable "azure_storage_account_key" {
description = "The Azure storage account key to use"
default = "<STORAGE_ACCOUNT_ID>"
}
        
variable "storage_account_resource_group" {
description = "The resource group where the storage account is setup"
default = "<RESOURCE_GROUP>"
}        
# Cosmos DB Configuration
variable "cosmos_total_throughput_limit" {
description = "Total throughput limit for Cosmos DB account"
default = 1000
}

variable "cosmos_location" {
description = "Azure region for Cosmos DB deployment"
default = "<LOCATION>"
}

variable "cosmos_zone_redundant" {
description = "Enable zone redundancy for Cosmos DB (requires region support and capacity)"
default = false
}

# AKS Configuration
variable "aks_resource_group" {
description = "The resource group where AKS has been setup"
default = "<RESOURCE_GROUP>"
}

variable "aks_cluster_name" {
description = "The name of the AKS cluster"
default = "<AKS_CLUSTER_NAME>"
}

variable "aks_host" {
description = "The AKS cluster API server endpoint"
default = "<AKS_HOST>"
}

variable "aks_client_certificate" {
description = "Base64 encoded client certificate for AKS authentication"
default = "<AKS_CLIENT_CERT>"
}

variable "aks_client_key" {
description = "Base64 encoded client key for AKS authentication"
default = "<AKS_CLIENT_KEY>"
}

variable "aks_cluster_ca_certificate" {
description = "Base64 encoded cluster CA certificate for AKS"
default = "<AKS_CA_CERT>"
}

variable "aks_node_resource_group" {
description = "The resource group containing AKS worker nodes"
default = "<NODE_RG>"
}

# Database Configuration
variable "postgres_db_name" {
description = "Name of the PostgreSQL database"
default = "execution_info"
}

variable "postgres_fqdn" {
description = "Fully qualified domain name of the PostgreSQL server"
default = "<POSTGRES_FQDN>"
}

# Identity and Security
variable "workload_identity_client_id" {
description = "Client ID for workload identity"
default = "<WORKLOAD_IDENTITY_CLIENT_ID>"
}

variable "keyvault_name" {
description = "Name of the Azure Key Vault"
default = "<KEYVAULT_NAME>"
}

variable "keyvault_identity_client_id" {
description = "Client ID for Key Vault managed identity"
default = "<KEYVAULT_IDENTITY_CLIENT_ID>"
}

# Networking

variable "hub_vnet_name" {
description = "The name of the hub vnet"
}

variable "hub_subnet_name" {
description = "The name of the hub subnet"
}

# Service Configuration
variable "kyuubi_host" {
description = "Hostname for Kyuubi service"
default = "<KRYUBI_HOST>"
}

variable "kyuubi_port" {
description = "Port number for Kyuubi service"
default = <KYUUBI_PORT>
}

# Domain Configuration
variable "hub_domain" {
description = "Domain name you control for the hub service"
default = "<HUB_DOMAIN>"
}

variable "ui_domain" {
description = "Domain name you control for the UI service"
default = "<UI_DOMAIN>"
}

variable "spark_history_server_url" {
description = "The url of the spark history server"
default = "<SPARK_HISTORY_SERVER_URL>"
}

# Domain Configuration

variable "hub_domain" {
description = "The domain to use for initializing the Zipline Hub. This should be a domain you can set DNS records for."
default = "<HUB_DOMAIN>"
}

variable "ui_domain" {
description = "The domain to use for initializing the Zipline UI. This should be a domain you can set DNS records for."
default = "<UI_DOMAIN>"
}


variable "admin_email" {
description = "Email for receiving certificate updates"
default = "<ADMIN_EMAIL>"
}
        
# Authentication and Access

variable "enable_oauth" {
description = "Whether to use oauth to authenticate access to the Zipline Hub"
default = true
}
        
variable "oauth_client_id" {
description = "Existing OAuth2 Client ID. If empty, a new App Registration will be created"
default = ""
}

variable "oauth_client_secret" {
description = "Existing OAuth2 Client Secret. Required if oauth_client_id is set"
default = ""
sensitive = true
}


variable "email_domains" {
description = "List of allowed email domains for OAuth2 Proxy. Use ['*'] to allow any domain"
default = ["*"]
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
default = "<LOG_ANALYTICS_WORKSPACE_ID>"
}
```

### 2.3 Apply Zipline Core to Your Azure Environment

```bash
cd zipline-core
terraform init
terraform plan
terraform apply
```

### 2.4 Set DNS Records for the Hub and UI domains

Use the outputted hub_address and ui_address to set DNS A records:
```
--------------------------------------------------------------------------------
DNS CONFIGURATION REQUIRED
--------------------------------------------------------------------------------
To enable HTTPS access and allow Cert-Manager to issue certificates,
please configure the following A Records in your DNS provider settings:

RECORD 1 (Hub):
  - Host/Name:  <HUB_DOMAIN>
  - Type:       A
  - Value:      <outputs.hub_address>

RECORD 2 (UI):
  - Host/Name:  <UI_DOMAIN>
  - Type:       A
  - Value:      <outputs.ui_address>

--------------------------------------------------------------------------------
Once configured, please allow a few minutes for DNS propagation.
Cert-Manager will automatically provision TLS certificates once the records resolve.
--------------------------------------------------------------------------------
```

## 3. Artifact Setup

### 3.1 Sync Zipline Engine Artifacts
Run the provided script to update the Zipline Engine Artifacts in Azure Storage

Use the artifacts_prefix output from running terraform in zipline-core/

```bash
cd .. # Back to infra-azure-internal/
ARTIFACT_PREFIX=<outputs.artifact_prefix>
VERSION=<LATEST_ZIPLINE_VERSION>
./zipline-artifacts-sync.sh --artifact_prefix $ARTIFACT_PREFIX --version $VERSION
```

### 3.2 Install the Zipline CLI
Use the same values for installing the Zipline CLI with the helper script.
```bash
ARTIFACT_PREFIX=<outputs.artifact_prefix>
VERSION=<LATEST_ZIPLINE_VERSION>
./zipline-cli-install.sh --artifact_prefix $ARTIFACT_PREFIX --version $VERSION
```

## Important Notes
- The provided certificates and keys are sensitive - store them securely
- Some resources may take several minutes to provision
- Ensure you have appropriate Azure permissions before running these configurations
