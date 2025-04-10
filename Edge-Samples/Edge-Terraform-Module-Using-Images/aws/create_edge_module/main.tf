terraform {
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.20.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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

locals {
  latitude = local.matching_location[0].lat
}

locals {
  longitude = local.matching_location[0].lng
}


# Get the access token. This is short lived. Hence there will be multiple requests
provider "restapi" {
  alias    = "token_api"
  uri      = var.api_endpoints.api_token_url
  headers  = {
    "Content-Type": "application/x-www-form-urlencoded"
  }
  create_returns_object   = true
}
resource "restapi_object" "access_token" {
  provider     = restapi.token_api
  path         = format("?refresh_token=%s",var.admin_refresh_token)
  data = jsonencode({})
  id_attribute = "token_type"
}

# Create the Provider
provider "restapi" {
  alias    = "provider_api"
  uri      = var.api_endpoints.create_provider_url
  headers  = {
    "Content-Type": "application/json",
    "accept": "application/json",
    "Authorization": "Bearer ${jsondecode(restapi_object.access_token.api_response).access_token}"
  }
  create_returns_object   = true
  debug = true
}

resource "restapi_object" "create_provider" {
  depends_on = [resource.restapi_object.access_token]
  provider     = restapi.provider_api
  path         = ""
  data = jsonencode({
    "providerLabel": "view",
    "name": var.provider_name,
    "description": "Provider Instance description",
    "orgId": var.org_id,
    "providerDetails": {
      "method": "ByViewConnectionServerCredentials",
      "data": {
        "viewProviderType": var.provider_type,
        "isFederatedArchitectureType": var.is_federated,
        "geoLocationLat": format("%s",local.latitude),
        "geoLocationLong": format("%s",local.longitude),

      }
    }
  })

  id_attribute = "id"
  create_method = "POST"
}

# Create the Edge 
provider "restapi" {
  alias    = "edge_api"
  uri      = var.api_endpoints.create_edge_url
  headers  = {
    "Content-Type": "application/json",
    "accept": "application/json",
    "Authorization": "Bearer ${jsondecode(restapi_object.access_token.api_response).access_token}"
  }
  create_returns_object   = true
  debug = true
}

resource "restapi_object" "create_edge" {
  depends_on = [resource.restapi_object.create_provider]
  provider     = restapi.edge_api
  path         = ""
  data = jsonencode({
    "name": var.edge_name,
    "description": "Edge description",
    "fqdn": var.edge_fqdn,
    "enablePrivateEndpoint": "False",
    "orgId": var.org_id,
    "providerInstanceId": jsondecode(restapi_object.create_provider.api_response).id,
    "deploymentModeDetails": {
      "type": "VM"
    },
    "agentMonitoringConfig": {
      "monitoringEnabled": "True"
    }
  })
  #
  id_attribute = "id"
  create_method = "POST"
}

# Pause for a minute
resource "null_resource" "wait_1_minutes" {
  depends_on = [resource.restapi_object.create_edge]
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

# Get the pairing code of the edge
data "http" "get_pairing_code" {
  depends_on = [resource.null_resource.wait_1_minutes]

  url = format("%s/%s/%s", var.api_endpoints.create_edge_url, jsondecode(restapi_object.create_edge.api_response).id , var.api_endpoints.pairing_code_url_suffix)
  method  = "GET"
  request_headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer ${jsondecode(restapi_object.access_token.api_response).access_token}"
    "accept" : "application/json"
  }

}

locals {
  pairing_code = jsondecode(data.http.get_pairing_code.response_body).pairingCode
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.aws_vpc] 
  }
}

data "aws_security_group" "security_group" {
  filter {
    name   = "group-name"
    values = [var.aws_security_group] 
  }
  vpc_id = data.aws_vpc.vpc.id
}

resource "aws_instance" "ec2" {
  depends_on = [data.aws_security_group.security_group]
  ami           = var.aws_ami_id
  instance_type = var.ec2_instance_type
  subnet_id     = var.aws_subnet_id
  private_ip    = var.static_ip_address
  iam_instance_profile = var.instance_profile
  vpc_security_group_ids = [data.aws_security_group.security_group.id]
  associate_public_ip_address = var.ec2_associate_public_ip_address 
  root_block_device {
    volume_size = var.volume_size  
    volume_type = var.volume_type         
  }
  user_data = <<-EOF
    #! /bin/bash
    /usr/bin/python3 /opt/horizon/bin/configure-adapter.py --sshEnable
    sudo useradd ${var.aws_ec2_username}
    echo -e '${var.aws_ec2_password}\n${var.aws_ec2_password}' | passwd ${var.aws_ec2_username}
    sudo /opt/horizon/bin/pair-edge.sh ${local.pairing_code}
  EOF
  tags = {
    Name = var.edge_name
  }
  lifecycle { 
    prevent_destroy = true
  }
}

# Get the access token.
provider "restapi" {
  alias    = "regenerate_token"
  uri      = var.api_endpoints.api_token_url
  headers  = {
    "Content-Type": "application/x-www-form-urlencoded"
  }
  create_returns_object   = true
  debug = true
}
resource "restapi_object" "regenerate_token" {
  depends_on = [resource.aws_instance.ec2]
  provider     = restapi.regenerate_token
  path         = format("?refresh_token=%s",var.admin_refresh_token)
  data = jsonencode({})
  #
  id_attribute = "token_type"
}

# Poll for edge status for POST_PROVISIONING_CONFIG_IN_PROGRESS
# script will exit with return code of 1 if the required state is not seen 
resource "null_resource" "get_edge_status" {
  depends_on = [resource.restapi_object.regenerate_token]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/CheckEdgeStatus.py $URL $TOKEN $ITERATIONS $WAIT_TIME"

    environment = {
      URL = format("%s/%s", var.api_endpoints.create_edge_url , jsondecode(restapi_object.create_edge.api_response).id)
      TOKEN = jsondecode(restapi_object.regenerate_token.api_response).access_token
      ITERATIONS = var.poll_iterations
      WAIT_TIME = var.wait_time
    }
  }
}

# Get the access token.
provider "restapi" {
  alias    = "regenerate_access_token"
  uri      = var.api_endpoints.api_token_url
  headers  = {
    "Content-Type": "application/x-www-form-urlencoded"
  }
  create_returns_object   = true
}
resource "restapi_object" "regenerate_access_token" {
  #depends_on = [resource.null_resource.get_edge_status]
  provider     = restapi.regenerate_access_token
  path         = format("?refresh_token=%s",var.admin_refresh_token)
  data = jsonencode({})
  id_attribute = "token_type"
}

# perform connection server configuration on the edge
# script will exit with return code of 1 if the configuration fails 
resource "null_resource" "cs_configure" {
  depends_on = [resource.restapi_object.regenerate_access_token]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/ConfigureCS.py $URL $TOKEN $ORG_ID $PROVIDER_NAME $CS_URL $CS_DOMAIN $CS_USER $CS_PASSWD"
    environment = {
      URL = format("%s/%s", var.api_endpoints.cs_configure_url, jsondecode(restapi_object.create_provider.api_response).id)
      TOKEN = jsondecode(restapi_object.regenerate_access_token.api_response).access_token
      ORG_ID = var.org_id
      PROVIDER_NAME = var.provider_name
      CS_URL = var.connection_server_url
      CS_DOMAIN = var.connection_server_domain
      CS_USER = var.connection_server_username
      CS_PASSWD = var.connection_server_password
    }
  }
}
