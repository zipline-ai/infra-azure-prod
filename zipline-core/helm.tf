# Kubernetes Provider configuration

data "azurerm_client_config" "current" {}

###############################################################
# This ensures CRDs are fully established before your app tries to use them.
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.3"
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}

data "azurerm_user_assigned_identity" "workload_identity" {
  resource_group_name = var.aks_resource_group
  name                = var.workload_identity_name
}

# Deploy Zipline Orchestration using Helm

resource "helm_release" "zipline_orchestration" {
  name             = "zipline-orchestration"
  chart            = "../charts/zipline-orchestration" # Path to your local helm chart
  namespace        = "zipline-system"
  create_namespace = false

  values = [
    templatefile("${path.module}/helm-values.yaml.tpl", {
      customer_name   = var.customer_name
      azure_location  = var.location
      artifact_prefix = "https://${var.azure_storage_account_name}.blob.core.windows.net/${azurerm_storage_container.zipline_artifacts.name}"
      version         = var.zipline_version
      enable_oauth    = var.enable_oauth

      log_analytics_workspace_id = var.log_analytics_workspace_workspace_id
      prometheus_query_endpoint  = azurerm_monitor_workspace.aks.query_endpoint
      prometheus_namespace       = kubernetes_namespace_v1.zipline_system.id
      grafana_endpoint           = azurerm_dashboard_grafana.aks.endpoint

      azure_storage_account_name = var.azure_storage_account_name
      azure_storage_account_key  = var.azure_storage_account_key

      orchestration_db_fqdn     = var.postgres_fqdn
      orchestration_db_database = var.postgres_db_name
      orchestration_db_username = data.azurerm_user_assigned_identity.workload_identity.name

      cosmos_table_partitions_dataset     = "TABLE_PARTITIONS"
      cosmos_data_quality_metrics_dataset = "DATA_QUALITY_METRICS"

      kyuubi_host = var.kyuubi_host != "" ? var.kyuubi_host : "${var.customer_name}-zipline-kyuubi.${var.location}.cloudapp.azure.com"
      kyuubi_port = var.kyuubi_port
      kyuubi_auth_enabled = var.enable_kyuubi_auth

      spark_history_server_url = var.spark_history_server_url

      workload_identity_client_id = data.azurerm_user_assigned_identity.workload_identity.client_id
      workload_identity_name      = data.azurerm_user_assigned_identity.workload_identity.name
      image_pull_secret_name      = kubernetes_secret_v1.docker_hub_creds.metadata[0].name

      keyvault_name                  = var.keyvault_name
      tenant_id                      = data.azurerm_client_config.current.tenant_id
      keyvault_identity_client_id    = var.keyvault_identity_client_id

      orchestration_hub_static_ip_name = azurerm_public_ip.hub_ingress.name
      orchestration_hub_static_ip      = azurerm_public_ip.hub_ingress.ip_address
      orchestration_ui_static_ip_name  = azurerm_public_ip.ui_ingress.name
      orchestration_ui_static_ip       = azurerm_public_ip.ui_ingress.ip_address

      hub_dns_name = "${var.hub_domain}"
      ui_dns_name  = "${var.ui_domain}"
      cert_manager_email = var.admin_email

      node_resource_group              = var.aks_node_resource_group
    })
  ]

  depends_on = [
    kubernetes_secret_v1.docker_hub_creds,
    helm_release.cert_manager
  ]
}

#################################################################
# Kubernetes Secrets and SecretProviderClass for AKS to access Azure Key Vault

resource "kubernetes_namespace_v1" "zipline_system" {
  metadata {
    name = "zipline-system"
  }

}

resource "kubernetes_secret_v1" "docker_hub_creds" {
  metadata {
    name      = "docker-hub-creds"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = "ziplineai"
          password = var.docker_token
          auth = base64encode("ziplineai:${var.docker_token}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace_v1.zipline_system]
}

#############################################################

resource "azurerm_public_ip" "hub_ingress" {
  name                = "${var.customer_name}-zipline-hub-pip"
  resource_group_name = var.aks_node_resource_group
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "ui_ingress" {
  name                = "${var.customer_name}-zipline-ui-pip"
  resource_group_name = var.aks_node_resource_group
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ------------------------------------------------------------------
# AUTHENTICATION SETUP (OAuth2 Proxy + Azure AD)
# ------------------------------------------------------------------

# Logic: Determine if we need to create resources or use provided ones
locals {
  # If no external ID is provided, we create the App Registration
  create_auth_app = var.oauth_client_id == "" && var.enable_oauth

  # Select the final credentials to pass to Helm
  final_client_id     = local.create_auth_app ? azuread_application.zipline_auth[0].client_id : var.oauth_client_id
  final_client_secret = local.create_auth_app ? azuread_application_password.zipline_auth[0].value : var.oauth_client_secret
  oauth2_config_file = <<-EOT
    provider = "azure"
    oidc_issuer_url = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
    email_domains = ${jsonencode(var.email_domains)}
    upstreams = [ "file:///dev/null" ]
  EOT
}

# 1. Generate a random cookie secret for OAuth2 Proxy
resource "random_password" "oauth2_cookie_secret" {
  length  = 32
  special = true
}

resource "random_uuid" "auth_scope_id" {}

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

resource "azuread_application" "zipline_auth" {
  count        = local.create_auth_app ? 1 : 0
  display_name = "${var.customer_name}-zipline-auth"
  identifier_uris = ["api://${var.customer_name}-zipline-auth"]
  required_resource_access {
    # Microsoft Graph API
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      # User.Read permission
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
  api {
    requested_access_token_version = 2
    # Pre-authorize the Azure CLI Client ID
    known_client_applications = ["04b07795-8ddb-461a-bbee-02f9e1bf7b46"]
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access Zipline on your behalf."
      admin_consent_display_name = "Access Zipline"
      enabled                    = true
      id                         = random_uuid.auth_scope_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to access Zipline on your behalf."
      user_consent_display_name  = "Access Zipline"
      value                      = "user_impersonation"
    }
  }
  web {
    redirect_uris = [
      "https://${var.hub_domain}/oauth2/callback",
      "https://${var.ui_domain}/oauth2/callback"
    ]
  }
}

resource "azuread_service_principal" "zipline_auth" {
  count     = local.create_auth_app ? 1 : 0
  client_id = azuread_application.zipline_auth[0].client_id
}

resource "azuread_service_principal_delegated_permission_grant" "zipline_auth_graph_grant" {
  count = local.create_auth_app ? 1 : 0

  service_principal_object_id          = azuread_service_principal.zipline_auth[0].object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["User.Read"] # This must match the scope requested in required_resource_access
}

resource "azuread_application_password" "zipline_auth" {
  count          = local.create_auth_app ? 1 : 0
  application_id = azuread_application.zipline_auth[0].id
}

# 3. Deploy OAuth2 Proxy via Helm
resource "helm_release" "oauth2_proxy" {
  count      = var.enable_oauth ? 1 : 0
  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.7.0"
  namespace  = "zipline-system"

  values = [
    yamlencode({
      image = {
        tag = "v7.7.0"
      }
      extraArgs = {
        "oidc-extra-audience" = "api://${var.customer_name}-zipline-auth"
        "skip-jwt-bearer-tokens" = "true"
      }
      config = {
        # Use the locals calculated above
        clientID     = local.final_client_id
        clientSecret = local.final_client_secret
        cookieSecret = random_password.oauth2_cookie_secret.result

        # Dynamic Config File based on Provider
        configFile   = local.oauth2_config_file
      }
      ingress = { enabled = false }
    })
  ]

  depends_on = [kubernetes_namespace_v1.zipline_system]
}

resource "kubernetes_ingress_v1" "oauth2_hub" {
  count      = var.enable_oauth ? 1 : 0
  metadata {
    name      = "oauth2-proxy-hub"
    namespace = "zipline-system"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/proxy-buffer-size" = "32k"
    }
  }
  spec {
    ingress_class_name = "nginx-hub" # Must match your Hub Controller
    rule {
      host = var.hub_domain
      http {
        path {
          path = "/oauth2"
          path_type = "Prefix"
          backend {
            service {
              name = "oauth2-proxy"
              port { number = 80 }
            }
          }
        }
      }
    }
    tls {
      hosts       = [var.hub_domain]
      secret_name = "hub-tls-secret" # Re-use the existing cert secret
    }
  }
}

# This adds the /oauth2 path to your existing UI domain
resource "kubernetes_ingress_v1" "oauth2_ui" {
  count = var.enable_oauth ? 1 : 0
  metadata {
    name      = "oauth2-proxy-ui"
    namespace = "zipline-system"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/proxy-buffer-size" = "32k"
    }
  }
  spec {
    ingress_class_name = "nginx-ui" # Must match your UI Controller
    rule {
      host = var.ui_domain
      http {
        path {
          path = "/oauth2"
          path_type = "Prefix"
          backend {
            service {
              name = "oauth2-proxy"
              port { number = 80 }
            }
          }
        }
      }
    }
    tls {
      hosts       = [var.ui_domain]
      secret_name = "ui-tls-secret" # Re-use the existing cert secret
    }
  }
}

#############################################################

output "oauth_app_client_id" {
  description = "The Client ID of the created Azure AD Application for OAuth."
  value       = local.create_auth_app ? azuread_application.zipline_auth[0].client_id : var.oauth_client_id
}

output "hub_address" {
  value = azurerm_public_ip.hub_ingress.ip_address
}

output "ui_address" {
  value = azurerm_public_ip.ui_ingress.ip_address
}

output "dns_setup_instructions" {
  description = "Instructions for configuring DNS records"
  value       = <<EOT

--------------------------------------------------------------------------------
DNS CONFIGURATION REQUIRED
--------------------------------------------------------------------------------
To enable HTTPS access and allow Cert-Manager to issue certificates,
please configure the following A Records in your DNS provider settings:

RECORD 1 (Hub):
  - Host/Name:  ${var.hub_domain}
  - Type:       A
  - Value:      ${azurerm_public_ip.hub_ingress.ip_address}

RECORD 2 (UI):
  - Host/Name:  ${var.ui_domain}
  - Type:       A
  - Value:      ${azurerm_public_ip.ui_ingress.ip_address}

--------------------------------------------------------------------------------
Once configured, please allow a few minutes for DNS propagation.
Cert-Manager will automatically provision TLS certificates once the records resolve.
--------------------------------------------------------------------------------
EOT
}

#############################################################
# Kyuubi Deployment
#############################################################

# Kyuubi namespace (deployed to kyuubi cluster)
resource "kubernetes_namespace_v1" "kyuubi" {
  count = var.kyuubi_host == "" ? 1 : 0
  provider = kubernetes.kyuubi

  metadata {
    name = "kyuubi"
  }
}

# Deploy Kyuubi using Helm (to kyuubi cluster)
resource "helm_release" "kyuubi" {
  count = var.kyuubi_host == "" ? 1 : 0
  provider = helm.kyuubi

  name             = "kyuubi"
  chart            = "../charts/kyuubi"
  namespace        = "kyuubi"
  create_namespace = false

  values = [
    templatefile("${path.module}/kyuubi-values.yaml.tpl", {
      workload_identity_client_id = var.kyuubi_workload_identity_client_id
      azure_storage_account_name  = var.azure_storage_account_name
      kyuubi_dns_label            = "${var.customer_name}-zipline-kyuubi"
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.kyuubi,
  ]
}