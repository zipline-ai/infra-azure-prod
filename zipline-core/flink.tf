# Flink on AKS Configuration
# Kubernetes resources for Flink jobs with Azure Workload Identity support.

resource "kubernetes_namespace_v1" "zipline_flink" {
  metadata {
    name = var.flink_aks_namespace
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}

# Install Flink Kubernetes Operator — webhook disabled to avoid needing cert-manager
# integration for the admission webhook (cert-manager is present but this keeps
# the setup simpler).
resource "helm_release" "flink_operator" {
  name             = "flink-kubernetes-operator"
  repository       = "https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.14.0/"
  chart            = "flink-kubernetes-operator"
  namespace        = "flink-operator"
  version          = "1.14.0"
  create_namespace = true

  set = [
    {
      name  = "webhook.create"
      value = "false"
    }
  ]

  depends_on = [kubernetes_namespace_v1.zipline_flink]
}

# Explicitly manage the FlinkDeployment CRD via kubectl_manifest so that
# tofu apply recreates it if deleted out-of-band. Helm skips CRD reinstallation
# by design, so this is the only reliable way to keep the CRD in sync with state.
resource "kubectl_manifest" "flinkdeployments_crd" {
  yaml_body = file("${path.module}/crds/flinkdeployments.flink.apache.org-v1.yml")

  depends_on = [helm_release.flink_operator]
}

# Service account for Flink job pods, annotated with the Flink workload identity
# client ID so AKS Workload Identity injects the federated token for ABFS access.
resource "kubernetes_service_account_v1" "flink_job" {
  metadata {
    name      = var.flink_aks_service_account
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = var.flink_workload_identity_client_id
    }
  }

  depends_on = [
    helm_release.flink_operator,
    kubectl_manifest.flinkdeployments_crd,
  ]
}

# RBAC Role for Flink operator to manage job pods, configmaps, services, and ingresses.
resource "kubernetes_role_v1" "flink_role" {
  metadata {
    name      = "flink-role"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }

  # Ingress management for Flink UI routing via nginx-hub
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }

  depends_on = [helm_release.flink_operator]
}

resource "kubernetes_role_binding_v1" "flink_role_binding" {
  metadata {
    name      = "flink-role-binding"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.flink_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flink_job.metadata[0].name
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  depends_on = [
    kubernetes_role_v1.flink_role,
    kubernetes_service_account_v1.flink_job,
  ]
}

# Role granting orchestration-sa permission to manage FlinkDeployments in zipline-flink.
# orchestration-sa (zipline-system) is the in-cluster identity used by AksFlinkSubmitter
# to create/get/delete FlinkDeployment CRs via the Kubernetes API.
resource "kubernetes_role_v1" "orchestration_flink_role" {
  metadata {
    name      = "orchestration-flink-role"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  rule {
    api_groups = ["flink.apache.org"]
    resources  = ["flinkdeployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Ingress management so AksFlinkSubmitter can create/delete per-deployment ingress rules
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [
    kubectl_manifest.flinkdeployments_crd,
    helm_release.flink_operator,
  ]
}

resource "kubernetes_role_binding_v1" "orchestration_flink_role_binding" {
  metadata {
    name      = "orchestration-flink-role-binding"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.orchestration_flink_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "orchestration-sa"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [kubernetes_role_v1.orchestration_flink_role]
}
