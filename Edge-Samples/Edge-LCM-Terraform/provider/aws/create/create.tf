# call the common create module for creating provider, edge, download the artifact 
# and the pairing code from admin portal
module "admin_create" {
  source = "../../../common/admin/create"
  config_data = var.config_data
  api_endpoints = var.api_endpoints
  platform = var.platform
  operation = var.operation
  temp_dir = var.temp_dir
}


# call post_deployment that pools for the edge status and configures conenction server 
module "post_deployment" {
  source = "../../../common/admin/post_deployment"
  config_data = var.config_data
  api_endpoints = var.api_endpoints
  platform = var.platform
  operation = var.operation
  temp_dir = var.temp_dir
  token = module.admin_create.token1
  edge_id = local.edge_id
  provider_id = local.provider_id
  depends_on = [resource.azurerm_virtual_machine_run_command.run_command]
}
