terraform {
  backend "azurerm" {
    resource_group_name  = "DefaultResourceGroup-WUS2"
    storage_account_name = "ziplineai2"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}