# Zipline Orchestration Helm Chart

This Helm chart deploys the Zipline Orchestration Platform with Temporal workflow engine on Azure Kubernetes Service (AKS).

## Prerequisites

Before installing this chart, you must have:

- An Azure Kubernetes Service (AKS) cluster
- Azure PostgreSQL Flexible Server instance
- Azure Key Vault instance
- Azure Storage Account
- Azure CLI installed
- kubectl installed and configured
- Helm 3.x installed

## Setting Up Azure Resources

### 1. Create Azure Resource Group

bash az group create --name <resource-group-name> --location

### 2. Create AKS Cluster

bash az aks create
--resource-group <resource-group-name>
--name <cluster-name>
--node-count 3
--enable-managed-identity
--generate-ssh-keys
--node-vm-size Standard_D8s_v6
--network-plugin azure

### 3. Create PostgreSQL Flexible Server

bash az postgres flexible-server create
--resource-group <resource-group-name>
--name <server-name>
--location
--admin-user locker_user
--storage-size 32768
--sku-name GP_Standard_D8ds_v5
--version 16

### 4. Create Database

bash az postgres flexible-server db create
--resource-group <resource-group-name>
--server-name <server-name>
--database-name execution_info

### 5. Create Key Vault

bash az keyvault create
--resource-group <resource-group-name>
--name <keyvault-name>
--location
--enable-rbac-authorization

## Installation

1. **Get AKS credentials**:

bash az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>

2. **Create a values file** (`values.yaml`):

global: 
   customer_name: "my-customer"
   artifact_prefix: "https://<storage-account>.blob.core.windows.net/warehouse" 
   version: "latest" # or specific version

cosmos:
   table_partitions_dataset: "TABLE_PARTITIONS"
   data_quality_metrics_dataset: "DATA_QUALITY_METRICS"

azure:
   location: "westus"
   storage_account_name: "<storage-account-name>"
   storage_account_key: "<storage-account-key>"
   log_analytics_workspace_id: "<workspace-id>"
   prometheus_query_endpoint: "<prometheus-endpoint>"
   prometheus_namespace: "<prometheus-namespace>"
   grafana_endpoint: "<grafana-endpoint>"

workloadIdentity:
   clientId: "<managed-identity-client-id>"

keyvault:
   name: "<keyvault-name>"
   tenantId: "<tenant-id>"
   userAssignedIdentityID: "<user-assigned-identity-id>"

kyuubi:
   host: "<kyuubi-host>"
   port: 10099
   credentials:
      enabled: true

spark:
   historyServerUrl: "<spark-history-server-url>"

# Optional: Configure custom domains
domains:
   ziplineUI: "ui.mydomain.com"
   hub: "hub.mydomain.com"

# Configure static IP addresses for ingresses
staticIPs:
   orchestrationUI: "<orchestration-ui-ip>"
   orchestrationUIName: "<orchestration-ui-name>"
   orchestrationHub: "<orchestration-hub-ip>"
   orchestrationHubName: "<orchestration-hub-name>"

database: 
   fqdn: "<postgres-server-name>.postgres.database.azure.com"
   database: "execution_info"


3. **Install the chart**:

bash helm install zipline-orchestration ./zipline-orchestration
-f values.yaml
--namespace zipline-system
--create-namespace


## Configuration

### Required Values

| Parameter | Description |
|-----------|-------------|
| `global.customer_name` | Customer identifier |
| `global.location` | Azure region |
| `global.artifact_prefix` | Storage account blob URL prefix |
| `global.version` | Zipline version to deploy |
| `database.host` | PostgreSQL server hostname |
| `database.username` | Database username |
| `database.password` | Database password |
| `database.database` | Database name |
| `keyVault.name` | Azure Key Vault name |
| `keyVault.tenantId` | Azure tenant ID |
| `identity.clientId` | Managed Identity client ID |
| `storage.accountName` | Azure Storage account name |

### Optional Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `domains.ziplineUI` | Custom domain for UI | `""` |
| `domains.hub` | Custom domain for Hub | `""` |

## Accessing Services

After deployment, services will be available at the configured ingress endpoints:

- **Zipline UI**: `https://ui.<domain>`
- **Orchestration Hub**: `https://hub.<domain>`

## Upgrading

To upgrade the chart:

bash helm upgrade zipline-orchestration ./zipline-orchestration
-f values.yaml
--namespace zipline-system

## Troubleshooting

1. **Check pod status**:

bash kubectl get pods -n zipline-system

2. **View pod logs**:

bash kubectl logs -n zipline-system <pod-name>

3. **Check Azure resources**:

az postgres flexible-server show
--resource-group <resource-group-name>
--name <server-name>

az keyvault show --name <keyvault-name>

## Uninstallation

To remove the Helm release:

bash helm uninstall zipline-orchestration --namespace zipline-system

Note: This will not delete the Azure resources (AKS, PostgreSQL, Key Vault, etc.). Those must be deleted separately if desired.