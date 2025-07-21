provider "aws" {
  region = ""
  access_key = ""
  secret_key = ""
  assume_role {
    role_arn = ""
  }
}
module "aws" {
  source = "../create_edge_module"
  # refer to ../create_edge_module/variables.tf to set the below parameters
  admin_refresh_token = ""
  org_id = ""
  provider_name = ""
  provider_type = "AWS"
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
  aws_vpc = ""
  aws_subnet_id = ""
  aws_ami_id = ""
  aws_security_group = ""
  aws_ec2_username = ""
  aws_ec2_password = ""
  ec2_instance_type = ""
  static_ip_address = ""
  volume_size = ""
  volume_type = ""
  instance_profile = ""
  ec2_associate_public_ip_address = 
}