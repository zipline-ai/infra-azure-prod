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

### Global & Azure Settings

| Parameter                | Description | Required |
|--------------------------|-------------|----------|
| `global.customer_name`   | Unique identifier for the customer environment | Yes | 
| `global.artifact_prefix` | Blob storage URL prefix for artifacts (e.g., https://<account>.blob.core.windows.net/<container>) | Yes |
| `global.version`         | Version tag for Zipline components (e.g., latest) | Yes |
| `azure.location`         | Azure region (e.g., westus) | Yes |
| `azure.storage_account_name` | Name of the Azure Storage Account | Yes |
| `azure.storage_account_key` | Access key for the storage account | Yes |
| `azure.log_analytics_workspace_id` | GUID for Log Analytics Workspace | Yes |
| `azure.prometheus_query_endpoint` | Endpoint for Azure Managed Prometheus | Yes |
| `azure.prometheus_namespace` | Prometheus namespace | Yes |
| `azure.grafana_endpoint` | Grafana endpoint | Yes |

### Identity & Security

| Parameter | Description | Required | 
|-----------|-------------|----------| 
| `workloadIdentity.clientId` | Client ID of the User Assigned Managed Identity used by the pods | Yes | 
| `keyvault.name` | Name of the Azure Key Vault | Yes | 
| `keyvault.tenantId` | Azure Tenant ID | Yes | 
| `keyvault.userAssignedIdentityID` | User Assigned Managed Identity ID | Client ID of the Identity used by the Key Vault CSI Driver (often same as workloadIdentity) | Yes |

### Database & Services

| Parameter | Description | Required | 
|-----------|-------------|----------| 
| `database.fqdn` | Full hostname of the PostgreSQL Flexible Server | Yes | 
| `database.database` | Name of the database (e.g., execution_info) | Yes | 
| `kyuubi.host` | Hostname or IP of the Kyuubi service | Yes | 
| `kyuubi.port` | Port for Kyuubi service (default 10099) | Yes | 
| `kyuubi.credentials.enabled` | Enable secret-based credentials for Kyuubi | No | 
| `spark.historyServerUrl` | URL for the Spark History Server | Yes | 
| `cosmos.table_partitions_dataset` | Cosmos DB dataset name | Yes |
| `cosmos.data_quality_metrics_dataset` | Cosmos DB dataset name | Yes |

### Network & Ingress

| Parameter | Description | Required | 
|-----------|-------------|----------| 
| `staticIPs.orchestrationUI` | Static IP address for the UI Ingress | Yes | 
| `staticIPs.orchestrationHub` | Static IP address for the Hub Ingress | Yes | 
| `domains.ziplineUI` | Custom DNS domain for the UI (e.g., ui.example.com) | No | 
| `domains.hub` | Custom DNS domain for the Hub (e.g., hub.example.com) | No |

## Accessing Services

After deployment, services will be available at the configured ingress endpoints:

- **Zipline UI**: `https://<ui-domain>`
- **Orchestration Hub**: `https://<hub-domain>`

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