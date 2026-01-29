global:
  customer_name: "${customer_name}"
  artifact_prefix: "${artifact_prefix}"
  version: "${version}"

imagePullSecrets:
  - name: "${image_pull_secret_name}"

# Ingress NGINX Controller for UI
ingress-nginx-ui:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx-ui
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-ui"
    ingressClass: nginx-ui
    service:
      loadBalancerIP: "${orchestration_ui_static_ip}"
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-resource-group: "${node_resource_group}"
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz"
    electionID: ingress-controller-leader-ui

# Ingress NGINX Controller for Hub
ingress-nginx-hub:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx-hub
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-hub"
    ingressClass: nginx-hub
    service:
      loadBalancerIP: "${orchestration_hub_static_ip}"
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-resource-group: "${node_resource_group}"
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz"
    electionID: ingress-controller-leader-hub

clusterIssuer:
  email: "${cert_manager_email}"

ingress:
  hub:
    className: nginx-hub
    host: "${hub_dns_name}"
    annotations:
      nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
      nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
      nginx.ingress.kubernetes.io/health-check-path: "/ping"
      nginx.ingress.kubernetes.io/proxy-body-size: "20m"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
  ui:
    className: nginx-ui
    host: "${ui_dns_name}"
    annotations:
      nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
      nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"

database:
  orchestration:
    fqdn: "${orchestration_db_fqdn}"
    database: "${orchestration_db_database}"
    username: "${orchestration_db_username}"

kyuubi:
  host: "${kyuubi_host}"
  port: "${kyuubi_port}"

cosmos:
  table_partitions_dataset: "${cosmos_table_partitions_dataset}"
  data_quality_metrics_dataset: "${cosmos_data_quality_metrics_dataset}"

azure:
  location: "${azure_location}"
  storage_account_name: "${azure_storage_account_name}"
  storage_account_key: "${azure_storage_account_key}"

workloadIdentity:
  clientId: "${workload_identity_client_id}"

keyvault:
  name: "${keyvault_name}"
  tenantId: "${tenant_id}"
  userAssignedIdentityID: "${keyvault_identity_client_id}"

staticIPs:
  orchestrationUI: "${orchestration_ui_static_ip}"
  orchestrationUIName: "${orchestration_ui_static_ip_name}"
  orchestrationHub: "${orchestration_hub_static_ip}"
  orchestrationHubName: "${orchestration_hub_static_ip_name}"
