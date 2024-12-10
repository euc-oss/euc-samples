# entry point for edge creation/upgrade
locals {
  is_windows = false
  temp_dir = var.linux_temp_dir
}

locals {
  config_data = jsondecode(file(var.config_file))
  platform = "azure"
}

provider "azurerm" {
  features {}
  client_id       = local.config_data.azure.credentials.client_id
  client_secret   = local.config_data.azure.credentials.client_secret
  tenant_id       = local.config_data.azure.credentials.tenant_id
  subscription_id = local.config_data.azure.credentials.subscription_id
}

# call the azure create module if the operation is create
module "azure_create" {
  source = "./create"
  count = (var.operation == "create") ? 1 : 0
  config_data = local.config_data
  api_endpoints = var.api_endpoints
  platform = var.platform
  operation = var.operation
  temp_dir = local.temp_dir
} 

