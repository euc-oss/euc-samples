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

output "output_provider" {
  value = module.admin_create.output_provider
}

output "output_edge" {
  value = module.admin_create.output_edge
}

locals {
  token = module.admin_create.new_token
  provider_id = module.admin_create.output_provider.id
  edge_id = module.admin_create.output_edge.id
}

output "name" {
  value = module.admin_create.download_image_name
}

output "path" {
  value = module.admin_create.download_image_name_path
}

resource "aws_s3_object" "vmdk_upload" {
  depends_on = [module.admin_create]
  bucket = var.config_data.aws.s3_bucket 
  key    = module.admin_create.download_image_name
  source = module.admin_create.download_image_name_path
}

resource "aws_ebs_snapshot_import" "terraform_snapshot" {
  depends_on = [resource.aws_s3_object.vmdk_upload]
    disk_container {
        format = "VMDK"
        user_bucket {
            s3_bucket = var.config_data.aws.s3_bucket
            s3_key    = module.admin_create.download_image_name
        }
    }
    role_name = var.config_data.aws.role_name
}

output "snapshot_id" {
  depends_on = [resource.aws_ebs_snapshot_import.terraform_snapshot]
  description = "The ID of the imported EBS snapshot"
  value       = aws_ebs_snapshot_import.terraform_snapshot.id
}

resource "aws_ami" "ami" {
  depends_on = [resource.aws_ebs_snapshot_import.terraform_snapshot]
  name                = var.config_data.aws.ami.name
  # Reference to these values are - 
  architecture        = "x86_64"
  virtualization_type = "hvm"
  root_device_name    = "/dev/sda1"
  ena_support         = true

  ebs_block_device {
    device_name = "/dev/sda1"
    snapshot_id = aws_ebs_snapshot_import.terraform_snapshot.id
  }
}

output "ami_id" {
  description = "The ID of the created AMI"
  value       = aws_ami.ami.id
}

data "aws_vpc" "target_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.config_data.aws.network.aws_vpc] 
  }
}

data "aws_subnet" "target_subnet" {
  filter {
    name   = "tag:Name"
    values =  [var.config_data.aws.network.aws_subnet]
  }

  vpc_id = data.aws_vpc.target_vpc.id
}

data "aws_security_group" "target_sg" {
  filter {
    name   = "group-name"
    values = [var.config_data.aws.security_group] 
  }

  vpc_id = data.aws_vpc.target_vpc.id
}

locals  {
  pairing_code = module.admin_create.output_pairing_code.pairingCode
}

output "pairing_code_from_admin_module" {
  value = local.pairing_code
}

resource "aws_instance" "ec2" {
  ami           = aws_ami.ami.id
  instance_type = var.config_data.aws.ec2.instance_type
  subnet_id     = data.aws_subnet.target_subnet.id
  private_ip    = var.config_data.aws.ec2.private_ip 
  vpc_security_group_ids = [data.aws_security_group.target_sg.id]
  associate_public_ip_address = var.config_data.aws.ec2.associate_public_ip_address 
  user_data = <<-EOF
    #! /bin/bash
    /usr/bin/python3 /opt/horizon/bin/configure-adapter.py --sshEnable
    sudo useradd ${var.config_data.aws.ec2.username}
    echo -e '${var.config_data.aws.ec2.password}\n${var.config_data.aws.ec2.password}' | passwd ${var.config_data.aws.ec2.username}
    sudo /opt/horizon/bin/pair-edge.sh ${local.pairing_code}
  EOF

  tags = {
    Name = var.config_data.aws.ec2.name
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
  token = module.admin_create.new_token
  edge_id = local.edge_id
  provider_id = local.provider_id
  depends_on = [resource.aws_instance.ec2]
}