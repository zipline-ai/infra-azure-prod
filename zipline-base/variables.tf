variable "customer_name" {
  description = "The unique name of the zipline customer"
}
variable "location" {
  description = "The Azure location to create resources in"
}

variable "azure_storage_account_id" {
  description = "The Azure storage account ID to use"
}

variable "subscription_id" {
  description = "The Azure subscription ID"
}

variable "acr_name" {
  description = "The ACR name"
  default     = ""
}

variable "acr_resource_group" {
  description = "The ACR resource group"
  default     = ""

}