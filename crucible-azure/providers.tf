terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # State lives alongside the zipline-core state in the same storage account
  # but under a separate key so crucible can be planned/applied independently.
  backend "azurerm" {
    resource_group_name  = "DefaultResourceGroup-WUS2"
    storage_account_name = "ziplineai2"
    container_name       = "tfstate"
    key                  = "crucible.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
