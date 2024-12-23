# entry point for edge creation/upgrade
locals {
  is_windows = false
  temp_dir = var.linux_temp_dir
}

locals {
  config_data = jsondecode(file(var.config_file))
  platform = "vsphere"
}

provider "vsphere" {
  user                 = local.config_data.vsphere.credentials.user
  password             = local.config_data.vsphere.credentials.password
  vsphere_server       = local.config_data.vsphere.credentials.vsphere_server
  allow_unverified_ssl = local.config_data.vsphere.credentials.allow_unverified_ssl
}

# call the aws create module if the is operation is create
module "vsphere_create" {
  source = "./create"
  count = (var.operation == "create") ? 1 : 0
  config_data = local.config_data
  api_endpoints = var.api_endpoints
  platform = var.platform
  operation = var.operation
  temp_dir = local.temp_dir
} 

