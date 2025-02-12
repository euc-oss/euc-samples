provider "azurerm" {
  features {}
  subscription_id = "" # azure subscription id
  use_msi = true
}

module "azure" {
  
  source = "../create_edge_module"

  # refer to ../create_edge_module/variables.tf to set the below parameters

  admin_refresh_token = ""
  org_id = ""
  provider_name = ""
  provider_type = "AZURE"
  is_federated = "true"
  edge_name = ""
  edge_fqdn = ""
  city = ""
  state = ""
  country = ""
  connection_server_url = ""
  connection_server_username = ""
  connection_server_password = ""
  connection_server_domain = ""
  azure_region = ""
  azure_virtual_network =  ""
  azure_subnet =  ""
  azure_network_resource_group = ""
  azure_image_name = ""
  azure_image_gallery_name = ""
  azure_image_resource_group = ""
  azure_image_version = ""
  vm_managed_disk_type =  ""
  vm_resource_group = ""
  vm_size =  ""
  static_ip_address = ""
  vm_admin_username = "ccadmin"
  vm_admin_password = ""

}