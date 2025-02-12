terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

# read the geo_data file for latitude and longitude information
data "local_file" "geo_data" {
  filename = "${path.module}/geolocations.json"
}


locals {
  cities = jsondecode(data.local_file.geo_data.content)
}
locals {
  matching_location = [
    for city in local.cities : city 
      if lower(city.city) == lower(var.city)
      && lower(city.state) == lower(var.state)
      && lower(city.country) == lower(var.country)
  ]
}
locals {
  match_found = length(local.matching_location) > 0
}
output "geo_location"{
  value = local.match_found  ? {
    city = local.matching_location[0].city
    latitude = local.matching_location[0].lat
    longitude = local.matching_location[0].lng
  } : null
  
}
resource "null_resource" "validate_location" {
  #depends_on = [null_resource.apply_trigger]
  count = local.match_found  ? 0  : 1
  provisioner "local-exec"{
    command = "echo 'please check city, state, country' && exit 1"
  }
}

# Get the access token. This is short lived. Hence there will be multiple requests
resource "null_resource" "get_token_request" {
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/TokenAuthorization.py $URL $TOKEN >  ${var.work_dir}/token_response.json"

    environment = {
      URL = var.api_endpoints.api_token_url
      TOKEN = var.admin_refresh_token
    }
  }

}
# read the response 
data "local_file" "response" {
  depends_on = [null_resource.get_token_request]
  filename   = "${var.work_dir}/token_response.json"
}

# Extract the token from the response JSON
output "token" {
  value = jsondecode(data.local_file.response.content).access_token
  sensitive = true
}

locals {
  token = jsondecode(data.local_file.response.content).access_token
}


# Create the Provider 
resource "null_resource" "create_provider" {
  depends_on = [null_resource.get_token_request]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/CreateProvider.py $URL $TOKEN $ORG_ID $LATITUDE $LONGITUDE $PROVIDER_NAME $PROVIDER_TYPE $IS_FEDERATED >  ${var.work_dir}/provider_response.json"
  
    environment = {
      URL = var.api_endpoints.create_provider_url
      TOKEN = local.token 
      ORG_ID = var.org_id
      LATITUDE = local.matching_location[0].lat 
      LONGITUDE = local.matching_location[0].lng
      PROVIDER_NAME = var.provider_name
      PROVIDER_TYPE = var.provider_type
      IS_FEDERATED = var.is_federated
    }
  }
}

# read the response 
data "local_file" "provider_response" {
  depends_on = [null_resource.create_provider]
  filename   = "${var.work_dir}/provider_response.json"
}

output "output_provider" {
  value = jsondecode(data.local_file.provider_response.content)
}
# extract the provider id
locals {
  provider_id = jsondecode(data.local_file.provider_response.content).id
}

# Create the Edge 
resource "null_resource" "create_edge" {
  count = var.operation == "create" ? 1 : 0
  depends_on = [null_resource.create_provider]
  triggers = {
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/CreateEdge.py $URL $TOKEN $EDGE_NAME $EDGE_FQDN $ORG_ID $PROVIDER_ID  >  ${var.work_dir}/edge_response.json"
    environment = {
      URL = var.api_endpoints.create_edge_url 
      TOKEN = local.token
      EDGE_NAME = var.edge_name
      EDGE_FQDN = var.edge_fqdn 
      ORG_ID = var.org_id
      PROVIDER_ID = local.provider_id
    }
  }
}

# read the response 
data "local_file" "edge_response" {
  depends_on = [null_resource.create_edge]
  filename   = "${var.work_dir}/edge_response.json"
}

output "output_edge" {
   value = jsondecode(data.local_file.edge_response.content)
}
# extract the edge id
locals {
  depends_on = [null_resource.create_edge]
  edge_id = jsondecode(data.local_file.edge_response.content).id
}


# get the download link for the edge 
data "http" "get_edge_config" {
  depends_on = [null_resource.get_token_request]
  url = var.api_endpoints.get_edge_config_url
  method  = "GET"
  request_headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer ${local.token}",
    "accept" : "application/json"
  }
    
}
output "get_edge_config_out" {
  value = jsondecode(data.http.get_edge_config.response_body)
}
output "edge_config_status" {
  value = data.http.get_edge_config.status_code
}
# Extract the path according to the platform  
locals {
  edge_config_data = jsondecode(data.http.get_edge_config.response_body)
  edge_image_data = [
    for item in local.edge_config_data : {
      url  = item.url
      name = item.name
    }
    if (
      (var.platform == "azure" && item.capacityType == "AZURE" && item.fileType == "ZIPPED_FILE") ||
      (var.platform == "ec2" && item.capacityType == "AWS" && item.fileType == "VMDK") ||
      (var.platform == "vsphere" && item.capacityType == "ON_PREM" && item.fileType == "OVA")
    )
  ][0]
  download_image_name = "${replace(local.edge_image_data.name, ".zip", "")}"
  download_image_url = local.edge_image_data.url
}

output "download_image_name" {
  value = local.download_image_name
}
locals {
  local_destination = "${var.work_dir}${local.edge_image_data.name}"
}

 locals {
  download_image_name_path = "${var.work_dir}${local.download_image_name}"
}

output "download_ova_url" {
  value = local.download_image_url
  
}

#download the edge artifact to the work_dir
resource "null_resource" "download_edge_image" {
  depends_on =  [null_resource.create_edge]
  
  provisioner "local-exec" {
    command = <<EOT
        if [ ! -f ${local.local_destination} ]; then
          echo "File does not exist. Downloading..."
          curl -L ${local.edge_image_data.url} -o ${local.local_destination}
        else
          echo "File already exists. Skipping download."
        fi
    EOT
  }
}

# Use unzip command to extract the archive if it is vhd.zip (azure only)
resource "null_resource" "extract_zip" {
  depends_on = [resource.null_resource.download_edge_image]
  provisioner "local-exec" {
    #command = local.final_command
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
        if [ ! -f "${var.work_dir}${local.download_image_name}" ] && [[ "${var.platform}" == "azure" ]]; then
          echo "vhd does not exist. Extracting..."
          unzip -o  ${var.work_dir}${local.edge_image_data.name} -d ${var.work_dir}
        else
          echo "vhd file already exists or platform not azure. Skipping extraction."
        fi
    EOT

  }
}


resource "null_resource" "azcopy_copy" {
  depends_on = [resource.null_resource.extract_zip]

  provisioner "local-exec" {
    command = <<EOT
      azcopy copy ${local.download_image_name_path} "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${data.azurerm_storage_container.container.name}${data.azurerm_storage_account_sas.token.sas}" --overwrite=false --log-level=INFO
    EOT
  }
}


# pause for a minute
resource "null_resource" "wait_1_minutes" {
  depends_on = [resource.null_resource.azcopy_copy]
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

resource "azurerm_image" "image" {
  depends_on = [resource.null_resource.wait_1_minutes]
  name                = var.azure_image_name
  resource_group_name = var.azure_image_resource_group
  location            = var.azure_region

  os_disk {
    storage_type = "Standard_LRS"
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = "https://${data.azurerm_storage_account.storage.name}.blob.core.windows.net/${data.azurerm_storage_container.container.name}/${local.download_image_name}"
  }

  lifecycle {
    prevent_destroy = true
  }
}


#fetch the token again as the token is short lived
resource "null_resource" "get_token_request1" {
  depends_on = [resource.azurerm_image.image]
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/TokenAuthorization.py $URL $TOKEN  >  ${var.work_dir}/response.json"
    environment = {
      URL = var.api_endpoints.api_token_url
      TOKEN = var.admin_refresh_token
    }
  }
}

data "local_file" "response1" {
  depends_on = [null_resource.get_token_request1]
  filename   = "${var.work_dir}/response.json"
}

# Extract the token from the response JSON
output "new_token" {
  value = jsondecode(data.local_file.response1.content).access_token
  sensitive = true
}

locals {
 new_token = jsondecode(data.local_file.response1.content).access_token
}

# get the pairing_code
resource "null_resource" "get_pairing_code" {
  depends_on =  [resource.null_resource.get_token_request1]
  triggers = {
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/PairingCode.py $URL $TOKEN >  ${var.work_dir}/pairing_response.json"
    environment = {
      URL = format("%s/%s/%s", var.api_endpoints.create_edge_url, local.edge_id, var.api_endpoints.pairing_code_url_suffix) 
      TOKEN = local.new_token
    }
  }
}

data "local_file" "pairing_code_response" {
  depends_on = [null_resource.get_pairing_code]
  filename   = "${var.work_dir}/pairing_response.json"
}

output "output_pairing_code" {
  depends_on = [null_resource.get_pairing_code]
  value = jsondecode(data.local_file.pairing_code_response.content)
}



data "azurerm_storage_account" "storage" {
  name                = var.azure_storage_account
  resource_group_name = var.azure_storage_resource_group
}


data "azurerm_storage_container" "container" {
  name                  = var.azure_container
  storage_account_name  = var.azure_storage_account
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


data "azurerm_subnet" "subnet" {
  name                 = var.azure_subnet
  virtual_network_name = var.azure_virtual_network
  resource_group_name  = var.azure_network_resource_group
}


data "azurerm_image" "image" {
  depends_on = [resource.azurerm_image.image]
  name                = var.azure_image_name
  resource_group_name = var.azure_image_resource_group
}

resource "azurerm_network_interface" "nic" {
  depends_on = [resource.azurerm_image.image]
  name                = var.edge_name
  location            = var.azure_region
  resource_group_name = var.vm_resource_group

  ip_configuration {
    name                          = var.edge_name
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = var.private_ip_address
  }
}

# create the azure vm
resource "azurerm_virtual_machine" "vm" {
  depends_on = [resource.azurerm_image.image]
  name                  = var.edge_name
  resource_group_name   = var.vm_resource_group
  location              = var.azure_region
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.vm_size

  # Use the existing image
  storage_image_reference {
    id = data.azurerm_image.image.id
  }

  storage_os_disk {
    name              = var.edge_name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.vm_managed_disk_type
  }

  os_profile {
    computer_name  = var.edge_name
    admin_username = var.vm_admin_username
    admin_password = var.vm_admin_password
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
  pairing_code = jsondecode(data.local_file.pairing_code_response.content).pairingCode
}


# run the pairing code script 
resource "azurerm_virtual_machine_run_command" "run_command" {
  depends_on = [resource.azurerm_virtual_machine.vm]
  name = var.edge_name
  virtual_machine_id = resource.azurerm_virtual_machine.vm.id
  location = var.azure_region
    source {
      script = <<SCRIPT_BLOCK
      sudo /opt/horizon/bin/pair-edge.sh ${local.pairing_code}
      SCRIPT_BLOCK
    }
}

# Extract the token from the response JSON
locals {
  token2 = jsondecode(data.local_file.response.content).access_token
}

# Poll for edge status for POST_PROVISIONING_CONFIG_IN_PROGRESS
# script will exit with return code of 1 if the required state is not seen 
resource "null_resource" "get_edge_status" {
  depends_on = [resource.azurerm_virtual_machine_run_command.run_command]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/CheckEdgeStatus.py $URL $TOKEN $ITERATIONS $WAIT_TIME >  ${var.work_dir}/edge_status_response.json"

    environment = {
      URL = format("%s/%s", var.api_endpoints.create_edge_url , local.edge_id)
      TOKEN = local.token2
      ITERATIONS = var.poll_iterations
      WAIT_TIME = var.wait_time
    }
  }
}

#token is valid for few mins. getting the token again
resource "null_resource" "get_token_request2" {
  depends_on = [resource.null_resource.get_edge_status]
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/TokenAuthorization.py $URL $TOKEN >  ${var.work_dir}/response2.json"
    environment = {
      URL = var.api_endpoints.api_token_url 
      TOKEN = var.admin_refresh_token
    }
  }
}

data "local_file" "response2" {
  depends_on = [null_resource.get_token_request2]
  filename   = "${var.work_dir}/response2.json"
}

# Extract the token from the response JSON
locals {
  token1 = jsondecode(data.local_file.response2.content).access_token
}

# perform connection server configuration on the edge
# script will exit with return code of 1 if the configuration fails 
resource "null_resource" "cs_configure" {
  depends_on = [resource.null_resource.get_token_request2, resource.null_resource.get_edge_status]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/ConfigureCS.py $URL $TOKEN $ORG_ID $PROVIDER_NAME $CS_URL $CS_DOMAIN $CS_USER $CS_PASSWD >  ${var.work_dir}/cs_response.json"
    environment = {
      URL = format("%s/%s", var.api_endpoints.cs_configure_url, local.provider_id)
      TOKEN = local.token1
      ORG_ID = var.org_id
      PROVIDER_NAME = var.provider_name
      CS_URL = var.connection_server_url
      CS_DOMAIN = var.connection_server_domain
      CS_USER = var.connection_server_username
      CS_PASSWD = var.connection_server_password
    }
  }
}
