
resource "null_resource" "apply_trigger" {}

# read the geo_data file for latitude and longitude information
data "local_file" "geo_data" {
  #depends_on = [null_resource.apply_trigger]
  filename = "${path.module}/geolocations.json"
}
locals {
  cities = jsondecode(data.local_file.geo_data.content)
}
locals {
  matching_location = [
    for city in local.cities : city 
      if lower(city.city) == lower(var.config_data.admin.location.city)
      && lower(city.state) == lower(var.config_data.admin.location.state)
      && lower(city.country) == lower(var.config_data.admin.location.country)
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
    command = "python3 ${path.module}/../../scripts/TokenAuthorization.py $URL $TOKEN >  ${path.module}/token_response.json"

    environment = {
      URL = var.api_endpoints.api_token_url
      TOKEN = var.config_data.admin.refresh_token
    }
  }

}
# read the response 
data "local_file" "response" {
  depends_on = [null_resource.get_token_request]
  filename   = "${path.module}/token_response.json"
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
  triggers = {
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/CreateProvider.py $URL $TOKEN $ORG_ID $LATITUDE $LONGITUDE $PROVIDER_NAME >  ${path.module}/provider_response.json"
  
    environment = {
      URL = var.api_endpoints.create_provider_url
      TOKEN = local.token 
      ORG_ID = var.config_data.admin.org_id
      LATITUDE = local.matching_location[0].lat 
      LONGITUDE = local.matching_location[0].lng
      PROVIDER_NAME = var.config_data.admin.provider_name
    }
  }
}

# read the response 
data "local_file" "provider_response" {
  depends_on = [null_resource.create_provider]
  filename   = "${path.module}/provider_response.json"
}

output "output_provider" {
  value = jsondecode(data.local_file.provider_response.content)
}
# extract the provier id 
locals {
  provider_id = jsondecode(data.local_file.provider_response.content).id
}

# Create the Edge 
resource "null_resource" "create_edge" {
  depends_on = [null_resource.create_provider]
  triggers = {
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/CreateEdge.py $URL $TOKEN $EDGE_NAME $EDGE_FQDN $ORG_ID $PROVIDER_ID  >  ${path.module}/edge_response.json"
    environment = {
      URL = var.api_endpoints.create_edge_url 
      TOKEN = local.token
      EDGE_NAME = var.config_data.admin.edge_name
      EDGE_FQDN = var.config_data.admin.edge_fqdn 
      ORG_ID = var.config_data.admin.org_id
      PROVIDER_ID = local.provider_id
    }
  }
}

# read the response 
data "local_file" "edge_response" {
  depends_on = [null_resource.create_edge]
  filename   = "${path.module}/edge_response.json"
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
      (var.platform == "ec2" && item.capacityType == "AWS" && item.fileType == "VMDK")
    )
  ][0]
  download_image_name = "${replace(local.edge_image_data.name, ".zip", "")}"
}

output "download_image_name" {
  value = local.download_image_name
}
locals {
  local_destination = "${var.temp_dir}${local.edge_image_data.name}"
}

output "download_image_name_path" {
  value = "${var.temp_dir}${local.download_image_name}"
}

#download the edge artifact to the temp_dir
resource "null_resource" "download_edge_image" {
  depends_on =  [data.http.get_edge_config]
  
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

locals {
  #unarchiver_command = (
    #var.temp_dir == var.windows_temp_dir ?
    #"powershell -Command \"Expand-Archive -Path ${var.temp_dir}${local.edge_image_data.name} -DestinationPath ${var.temp_dir} -Force\"" : "unzip -o  ${var.temp_dir}${local.edge_image_data.name} -d ${var.temp_dir}"
  #)

  #unarchiver_command = "unzip -o  ${var.temp_dir}${local.edge_image_data.name} -d ${var.temp_dir}"
  #final_command = (
  #  var.platform == "azure" ? local.unarchiver_command : "echo 'skipping extraction'"
  #)
}

# Use unarchiver_command to extract the archive if it is vhd.zip (azure only)
resource "null_resource" "extract_zip" {
  depends_on = [resource.null_resource.download_edge_image]
  provisioner "local-exec" {
    #command = local.final_command
    command = <<EOT
        if [ ! -f ${var.temp_dir}${local.download_image_name} ]; then
          echo "vhd does not exist. Extracting..."
          unzip -o  ${var.temp_dir}${local.edge_image_data.name} -d ${var.temp_dir}
        else
          echo "vhd file already exists. Skipping extraction."
        fi
    EOT
    
  }
}

#fetch the token again as the token is short lived
resource "null_resource" "get_token_request1" {
  depends_on = [resource.null_resource.download_edge_image]
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/TokenAuthorization.py $URL $TOKEN  >  ${path.module}/response.json"
    environment = {
      URL = var.api_endpoints.api_token_url
      TOKEN = var.config_data.admin.refresh_token
    }
  }
}

data "local_file" "response1" {
  depends_on = [null_resource.get_token_request1]
  filename   = "${path.module}/response.json"
}

# Extract the token from the response JSON
output "token1" {
  value = jsondecode(data.local_file.response1.content).access_token
  sensitive = true
}

locals {
 token1 = jsondecode(data.local_file.response1.content).access_token
}
# pause for a minute
resource "null_resource" "wait_1_minutes" {
  depends_on = [resource.null_resource.create_edge]
  triggers = {
      always = timestamp()
  }
  provisioner "local-exec" {
    command = "sleep 60"  
  }
}

# get the pairing_code
resource "null_resource" "get_pairing_code" {
  depends_on =  [resource.null_resource.wait_1_minutes]
  triggers = {
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/PairingCode.py $URL $TOKEN >  ${path.module}/pairing_response.json"
    environment = {
      URL = format("%s/%s/%s", var.api_endpoints.create_edge_url, local.edge_id, var.api_endpoints.pairing_code_url_suffix) 
      TOKEN = local.token1
    }
  }
}

data "local_file" "pairing_code_response" {
  depends_on = [null_resource.get_pairing_code]
  filename   = "${path.module}/pairing_response.json"
}

output "output_pairing_code" {
  depends_on = [null_resource.get_pairing_code]
  value = jsondecode(data.local_file.pairing_code_response.content)
}

