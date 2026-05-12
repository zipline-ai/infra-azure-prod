# crucible-azure

Terraform module that captures the **Crucible** infrastructure on Azure
(subscription `3cece986-9416-439c-98a6-441ff986c88d`, resource group
`crucible-rg`). The cluster, identity, and supporting resources were created
by hand during early Crucible development; this module formalizes them via
`import { }` blocks so future changes go through code review and `terraform
plan` rather than the portal.

## What's managed

| Resource | Name | Notes |
|---|---|---|
| `azurerm_resource_group.crucible` | `crucible-rg` | westus2 |
| `azurerm_kubernetes_cluster.crucible` | `crucible-aks` | OIDC + Workload Identity enabled; Azure CNI overlay |
| `azurerm_kubernetes_cluster_node_pool.*` | `nodepool1` (default) + `arm64`, `nvme`, `spotnvme`, `spotnvme2` | autoscale-from-zero on the optional pools |
| `azurerm_user_assigned_identity.spark` | `crucible-spark-identity` | Used by gateway + all tenant Spark/Flink SAs |
| `azurerm_federated_identity_credential.*` | 5 creds: `crucible-system:crucible`, `test-ns-{a,b}:spark-operator-spark`, `test-ns-{a,b}:flink` | claims-demo-hub creds intentionally unmanaged |
| `azurerm_key_vault.crucible` | `crucible-azure-kv` | RBAC-authorized |
| `azurerm_storage_container.crucible` | `crucible` on shared `ziplineai2` | Container only; account managed elsewhere |
| `azurerm_role_assignment.*` | UAMI grants on blob/RG/KV | Storage Blob Data Contributor/Owner + Managed Identity Contributor + User Access Administrator + KV Secrets User |

## First-time apply (importing live infra)

```sh
cd crucible-azure
terraform init
terraform plan        # should report imports, zero create/destroy
terraform apply       # applies imports + makes the state authoritative
```

After the import completes, subsequent `terraform plan` runs should produce
**no diff** while the live state matches the code. If a diff appears, either
the live state drifted (update it via terraform) or this module is
incomplete (update the code).

## State

Stored in the same Azure blob backend as `zipline-core/` but under a separate
key (`crucible.terraform.tfstate`) so this module can be planned and applied
independently.

## What's *not* here (yet)

- `azurerm_kubernetes_cluster.crucible` is currently created with the
  `SystemAssigned` identity. Crucible-side helm install + namespace
  onboarding logic still runs out-of-band; this module only owns the
  prerequisites.
- ACR (`ziplinecanary.azurecr.io`) lives in RG `dev` and is managed by
  whoever owns the canary subscription.
- Role assignments on the shared storage account in `DefaultResourceGroup-WUS2`
  reference resources we don't own; the assignments themselves are managed
  here.
- claims-demo-hub federations on the same UAMI are unmanaged on purpose —
  they belong to that demo project and should move with it.
