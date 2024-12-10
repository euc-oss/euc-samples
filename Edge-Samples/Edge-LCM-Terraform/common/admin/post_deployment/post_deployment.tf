#token is valid for few mins. getting the token again
resource "null_resource" "get_token_request" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/TokenAuthorization.py ${var.api_endpoints.api_token_url} ${var.config_data.admin.refresh_token} >  ${path.module}/response.json"
  }
}

data "local_file" "response" {
  depends_on = [null_resource.get_token_request]
  filename   = "${path.module}/response.json"
}

# Extract the token from the response JSON
locals {
  token = jsondecode(data.local_file.response.content).access_token
}

# Poll for edge status for POST_PROVISIONING_CONFIG_IN_PROGRESS
# script will exit with return code of 1 if the required state is not seen 
resource "null_resource" "get_edge_status" {
  depends_on = [resource.null_resource.get_token_request]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/CheckEdgeStatus.py $URL $TOKEN $ITERATIONS $WAIT_TIME >  ${path.module}/edge_status_response.json"

    environment = {
      URL = format("%s/%s", var.api_endpoints.create_edge_url , var.edge_id)
      TOKEN = local.token
      ITERATIONS = var.poll_iterations
      WAIT_TIME = var.wait_time
    }
  }
}

#token is valid for few mins. getting the token again
resource "null_resource" "get_token_request1" {
  depends_on = [resource.null_resource.get_edge_status]
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/TokenAuthorization.py $URL $TOKEN >  ${path.module}/response1.json"
    environment = {
      URL = var.api_endpoints.api_token_url 
      TOKEN = var.config_data.admin.refresh_token
    }
  }
}

data "local_file" "response1" {
  depends_on = [null_resource.get_token_request1]
  filename   = "${path.module}/response1.json"
}

# Extract the token from the response JSON
locals {
  token1 = jsondecode(data.local_file.response1.content).access_token
}

# perform connection server configuration on the edge
# script will exit with return code of 1 if the configuration fails 
resource "null_resource" "cs_configure" {
  depends_on = [resource.null_resource.get_token_request1]
  triggers = {
  }
  provisioner "local-exec" {
    command = "python3 ${path.module}/../../scripts/ConfigureCS.py $URL $TOKEN $ORG_ID $PROVIDER_NAME $CS_URL $CS_DOMAIN $CS_USER $CS_PASSWD >  ${path.module}/cs_response.json"
    environment = {
      URL = format("%s/%s", var.api_endpoints.cs_configure_url, var.provider_id)
      TOKEN = local.token1
      ORG_ID = var.config_data.admin.org_id
      PROVIDER_NAME = var.config_data.admin.provider_name
      CS_URL = var.config_data.connection_server.connection_server_url
      CS_DOMAIN = var.config_data.connection_server.connection_server_domain
      CS_USER = var.config_data.connection_server.connection_server_username 
      CS_PASSWD = var.config_data.connection_server.connection_server_password
    }
  }
}