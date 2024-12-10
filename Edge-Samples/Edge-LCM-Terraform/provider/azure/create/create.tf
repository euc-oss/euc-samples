
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


output "admin_create_out_token" {
  value = module.admin_create.token1
} 

output "output_provider" {
  value =  module.admin_create.output_provider
}

output "output_edge" {
  value =  module.admin_create.output_edge
}

locals {
  depends_on = [module.admin_create.output_edge]
  token = module.admin_create.token1
  provider_id = module.admin_create.output_provider.id
  edge_id = module.admin_create.output_edge.id
}

data "azurerm_storage_account" "storage" {
  name                = var.config_data.azure.storage_container.storage_account
  resource_group_name = var.config_data.azure.storage_container.resource_group
}


data "azurerm_storage_container" "container" {
  name                  = var.config_data.azure.storage_container.container
  storage_account_name  = var.config_data.azure.storage_container.storage_account
}

locals {
  start_time = timestamp()  
  expiry_time = timeadd(local.start_time, "2h")
}


data "azurerm_storage_account_sas" "token" {
  connection_string = data.azurerm_storage_account.storage.primary_connection_string
  # Define the permissions required for blob upload
  permissions {
    read   = true  # Allow read
    write  = true  # Allow write
    create = true  # Allow create (to upload new blobs)
    delete = false # No delete permission
    list   = false # No list permission
    add    = false # No add permission
    update = false # No update permission
    tag    = false # No tag permission
    filter = false # No filter permission
    process = false # No process permission
  }

  # Define the services allowed (only blob service is needed for your case)
  services {
    blob  = true  # Blob service is allowed
    file  = false # No file service needed
    queue = false # No queue service needed
    table = false # No table service needed
  }

  # Define the resource types (only container and object are relevant for blobs)
  resource_types {
    container = true  # SAS is for the container
    object    = true  # SAS is for the object (blobs)
    service   = false # No service type required
  }

  # Define the validity period of the SAS token, 2 hours
  start   = local.start_time
  expiry  = local.expiry_time
}


resource "null_resource" "azcopy_copy" {
  depends_on = [module.admin_create]

  provisioner "local-exec" {
    command = <<EOT
      azcopy copy ${module.admin_create.download_image_name_path} "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${data.azurerm_storage_container.container.name}${data.azurerm_storage_account_sas.token.sas}" --overwrite=false --log-level=INFO
    EOT
  }
}



resource "azurerm_image" "image" {
  depends_on = [resource.null_resource.azcopy_copy]
  name                = var.config_data.azure.image.name
  resource_group_name = var.config_data.azure.image.resource_group 
  location            = var.config_data.azure.region

  os_disk {
    storage_type = "Standard_LRS"
    os_type  = "Linux" 
    os_state = "Generalized"
    blob_uri = "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${data.azurerm_storage_container.container.name}/${module.admin_create.download_image_name}" 
  }
  lifecycle { 
    prevent_destroy = true
  }
}



data "azurerm_subnet" "subnet" {
  name                 = var.config_data.azure.network.subnet
  virtual_network_name = var.config_data.azure.network.virtual_network
  resource_group_name  = var.config_data.azure.network.resource_group
}


data "azurerm_image" "image" {
  depends_on = [resource.azurerm_image.image]
  name                = var.config_data.azure.image.name 
  resource_group_name = var.config_data.azure.image.resource_group
}

resource "azurerm_network_interface" "nic" {
  depends_on = [resource.azurerm_image.image]
  name                = var.config_data.admin.edge_name
  location            = var.config_data.azure.region
  resource_group_name = var.config_data.azure.vm.resource_group

  ip_configuration {
    name                          = var.config_data.admin.edge_name
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = var.config_data.azure.vm.private_ip_address
  }
}

# create the azure vm
resource "azurerm_virtual_machine" "vm" {
  depends_on = [resource.azurerm_image.image]
  name                  = var.config_data.admin.edge_name
  resource_group_name   = var.config_data.azure.vm.resource_group
  location              = var.config_data.azure.region
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.config_data.azure.vm.vm_size

  # Use the existing image
  storage_image_reference {
    id = data.azurerm_image.image.id
  }

  storage_os_disk {
    name              = var.config_data.admin.edge_name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.config_data.azure.vm.managed_disk_type
  }

  os_profile {
    computer_name  = var.config_data.admin.edge_name
    admin_username = var.config_data.azure.vm.credentials.admin_username
    admin_password = var.config_data.azure.vm.credentials.admin_password
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  lifecycle { 
    prevent_destroy = true
  }
}

output "vm_id" {
  depends_on = [resource.azurerm_virtual_machine.vm]
  value = resource.azurerm_virtual_machine.vm.id
}

locals  {
  pairing_code = module.admin_create.output_pairing_code.pairingCode
}

output "pairing_code_from_admin_module" {
  value = local.pairing_code
}
# run the pairing code script 
resource "azurerm_virtual_machine_run_command" "run_command" {
  name = var.config_data.admin.edge_name
  virtual_machine_id = resource.azurerm_virtual_machine.vm.id
  location = var.config_data.azure.region
    source {
      script = <<SCRIPT_BLOCK
      sudo /opt/vmware/bin/pair-edge.sh ${local.pairing_code}
      SCRIPT_BLOCK
    }
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

