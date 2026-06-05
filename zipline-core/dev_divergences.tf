data "azuread_application" "github_actions" {
  display_name = "github-actions-upload-platform"
}

# This ID is needed to grant permissions within Kubernetes
data "azuread_service_principal" "github_actions" {
  client_id = data.azuread_application.github_actions.client_id
}

# This role is scoped to the "zipline-system" namespace for security
resource "kubernetes_role_v1" "github_actions_updater" {
  metadata {
    name      = "github-actions-updater"
    namespace = "zipline-system" # Target namespace for your services
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "patch", "update"]
  }
}

# This gives your GitHub Actions workflow the permissions defined in the Role
resource "kubernetes_role_binding_v1" "github_actions_updater_binding" {
  metadata {
    name      = "github-actions-updater-binding"
    namespace = "zipline-system" # Must be the same namespace as the Role
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.github_actions_updater.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = data.azuread_service_principal.github_actions.object_id
  }
}

# GitHub Actions OIDC federated credentials.
# Azure requires exact subject matches (no wildcards). Using environment-based
# subjects so any ref (main, merge queue, etc.) can authenticate — the workflow
# just needs `environment: azure`. This is the Azure equivalent of GCP's repo-wide
# workload identity pool.
locals {
  github_repos = {
    "platform" = "zipline-ai/platform"
    "chronon"  = "zipline-ai/chronon"
    "infra"    = "zipline-ai/infra-azure-prod"
  }
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  for_each       = local.github_repos
  application_id = data.azuread_application.github_actions.id
  display_name   = "github-${each.key}"
  description    = "GitHub Actions from ${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value}:environment:azure"
}


# ------------------------------------------------------------------
# Hub API access — allow GitHub Actions SP to request tokens for the hub auth app
# ------------------------------------------------------------------

data "azuread_service_principal" "hub_auth" {
  count        = var.enable_oauth ? 1 : 0
  display_name = "dev-zipline-auth"
}

resource "azuread_app_role_assignment" "github_actions_hub_access" {
  count               = var.enable_oauth ? 1 : 0
  app_role_id         = "00000000-0000-0000-0000-000000000000" # default access
  principal_object_id = data.azuread_service_principal.github_actions.object_id
  resource_object_id  = data.azuread_service_principal.hub_auth[0].object_id
}

# ------------------------------------------------------------------
# Microsoft Entra directory roles for GitHub Actions
# ------------------------------------------------------------------

# zipline-core reads and manages application registrations, service principals,
# delegated permission grants, and groups via the azuread provider.
resource "azuread_directory_role" "application_administrator" {
  display_name = "Application Administrator"
}

resource "azuread_directory_role_assignment" "github_actions_application_administrator" {
  # role_id expects the stable directory role template UUID, not the activated
  # per-tenant directory role object ID returned in azuread_directory_role.id.
  role_id             = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
  principal_object_id = data.azuread_service_principal.github_actions.object_id

  depends_on = [azuread_directory_role.application_administrator]
}

resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "github_actions_directory_readers" {
  # role_id expects the stable directory role template UUID, not the activated
  # per-tenant directory role object ID returned in azuread_directory_role.id.
  role_id             = "88d8e3e3-8f55-4a1e-953a-9b9898b8876b"
  principal_object_id = data.azuread_service_principal.github_actions.object_id

  depends_on = [azuread_directory_role.directory_readers]
}

# ------------------------------------------------------------------
# Azure RBAC for GitHub Actions
# ------------------------------------------------------------------

# 1. Get the existing AKS Cluster resource
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group
}

# 2. Assign the "Azure Kubernetes Service Cluster User Role" to the Service Principal
# This allows the workflow to list cluster credentials and connect (aks-set-context)
resource "azurerm_role_assignment" "github_actions_aks_user" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

# 3. Grant Storage Account permissions for Terraform state (ziplineai2)
data "azurerm_storage_account" "tfstate" {
  name                = "ziplineai2"
  resource_group_name = "DefaultResourceGroup-WUS2"
}

resource "azurerm_role_assignment" "github_actions_storage_contributor" {
  scope                = data.azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_storage_blob_contributor" {
  scope                = data.azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

# zipline-core creates additional resource groups (for example Cosmos DB) and
# manages resources in the AKS-managed node resource group, so it needs
# subscription-wide Azure management permissions.
resource "azurerm_role_assignment" "github_actions_subscription_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_subscription_user_access_admin" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "User Access Administrator"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

# 4. Grant Azure management permissions for the base resource group so
# GitHub Actions can plan/apply those resources and create RBAC assignments.
resource "azurerm_role_assignment" "github_actions_hub_rg_contributor" {
  scope                = data.azurerm_resource_group.hub_rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_hub_rg_user_access_admin" {
  scope                = data.azurerm_resource_group.hub_rg.id
  role_definition_name = "User Access Administrator"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

# Shared ACR used by the base stack.
data "azurerm_container_registry" "ziplinecanary" {
  name                = "ziplinecanary"
  resource_group_name = "dev"
}

resource "azurerm_role_assignment" "github_actions_acr_contributor" {
  scope                = data.azurerm_container_registry.ziplinecanary.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_acr_user_access_admin" {
  scope                = data.azurerm_container_registry.ziplinecanary.id
  role_definition_name = "User Access Administrator"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}

#############################################################
# Apicurio Schema Registry
#############################################################

resource "azurerm_key_vault_secret" "apicurio_eventhubs_connection_string" {
  name         = "apicurio-eventhubs-connection-string"
  key_vault_id = data.azurerm_key_vault.main.id
  value        = var.event_hubs_connection_string
}

resource "kubernetes_secret_v1" "apicurio_kafka_jaas" {
  metadata {
    name      = "apicurio-kafka-jaas"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  data = {
    "jaas.config" = "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"${var.event_hubs_connection_string}\";"
  }

  depends_on = [kubernetes_namespace_v1.zipline_system]
}

resource "helm_release" "apicurio_registry" {
  name             = "apicurio-registry"
  repository       = "oci://ghcr.io/eshepelyuk/helm"
  chart            = "apicurio-registry"
  version          = "3.8.0"
  namespace        = kubernetes_namespace_v1.zipline_system.metadata[0].name
  create_namespace = false
  upgrade_install  = true

  values = [
    yamlencode({
      registry = {
        kafka = {
          bootstrapServers = "zipline-demo-events.servicebus.windows.net:9093"
        }
        extraEnv = [
          { name = "REGISTRY_KAFKA_COMMON_SECURITY_PROTOCOL", value = "SASL_SSL" },
          { name = "REGISTRY_KAFKA_COMMON_SASL_MECHANISM", value = "PLAIN" },
          {
            name = "REGISTRY_KAFKA_COMMON_SASL_JAAS_CONFIG"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret_v1.apicurio_kafka_jaas.metadata[0].name
                key  = "jaas.config"
              }
            }
          }
        ]
        ingress = { enabled = false }
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.zipline_system,
    kubernetes_secret_v1.apicurio_kafka_jaas,
  ]
}

# Build custom Spark image with Azure libraries (hadoop-azure, cosmos connector)
# and push to ACR. Uses az acr build with a remote git context so the Dockerfile
# in the chronon repo is the single source of truth — no duplication.
resource "null_resource" "spark_image_import" {
  triggers = {
    image_tag       = "3.5.3"
    dockerfile_repo = "https://github.com/zipline-ai/chronon.git"
    dockerfile_ref  = "main"
  }

  provisioner "local-exec" {
    command = <<-EOT
      az acr build \
        --registry ziplinecanary \
        --image spark-azure:3.5.3 \
        --platform linux/amd64 \
        --file azure.Dockerfile \
        https://github.com/zipline-ai/chronon.git#main:docker/spark
    EOT
  }
}

# Kafka JAAS config for Flink pods to authenticate against Event Hubs via SASL_SSL.
# Flink JM/TM pods run under zipline-flink-sa which cannot access Key Vault directly,
# so the connection string is materialized here as a Kubernetes Secret.
resource "kubernetes_secret_v1" "flink_kafka_jaas" {
  metadata {
    name      = "flink-kafka-jaas"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  data = {
    "jaas.config" = "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"${var.event_hubs_connection_string}\";"
  }

  depends_on = [kubernetes_namespace_v1.zipline_flink]
}
