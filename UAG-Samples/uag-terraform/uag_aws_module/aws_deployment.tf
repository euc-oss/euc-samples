terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    config = {
      source  = "alabuel/config"
      version = "0.2.8"
    }
  }
}

data "external" "config" {
  program = ["pwsh", "./AWS_Preparation.ps1"]
  query = merge({for key,value in local.ini_map[local.name] : key => value}, { inifile = var.iniFile})
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}

data "config_ini" "sensitive_ini" {
  ini = file(var.inputs)
}

locals {
  name     = var.uag_name
  count    = var.uag_count
  uagArray = {for i in range(1, local.count+1) : format("%s%d", local.name, i) => i}

  ini_map = jsondecode(data.config_ini.sensitive_ini.json)
}

resource "aws_network_interface" "nic" {
  for_each = {
    for i in [0, 1, 2] : "nic${i}" => {
      subnet_id       = lookup(data.external.config[0].result, "subnetId${i}", "")
      security_group  = lookup(data.external.config[0].result, "securityGroupId0", "")
    } if lookup(data.external.config[0].result, "subnetId${i}", "") != ""
  }

  subnet_id       = each.value.subnet_id
  security_groups = [each.value.security_group]

  tags = {
    Name = each.key
  }
}

data "aws_eip" "static_eip" {
  for_each = {
    for i in [0, 1, 2] : "nic${i}" => lookup(data.external.config[0].result, "publicIPId${i}", "")
    if lookup(data.external.config[0].result, "publicIPId${i}", "") != ""
  }
  id = each.value
}

resource "aws_eip" "dynamic_eip" {
  for_each = {
    for k, v in aws_network_interface.nic : k => v
    if !contains(keys(data.aws_eip.static_eip), k)
  }
  vpc = true
}

locals {
  eip_allocation_ids = {
    for k, nic in aws_network_interface.nic :
    k => (
      contains(keys(data.aws_eip.static_eip), k)
      ? data.aws_eip.static_eip[k].id
      : aws_eip.dynamic_eip[k].allocation_id
    )
  }
}

resource "aws_eip_association" "nic_assoc" {
  for_each = aws_network_interface.nic

  network_interface_id = each.value.id
  allocation_id        = local.eip_allocation_ids[each.key]
}


# Create a EC2 instance
resource "aws_instance" "uag-aws" {
  for_each = local.uagArray

  ami               = data.external.config[0].result.amiID
  instance_type     = data.external.config[0].result.instanceType
  user_data_base64  = data.external.config[0].result.userData

  tags = {
    Name = each.key
  }

  dynamic "network_interface" {
    for_each = aws_network_interface.nic
    content {
      network_interface_id = network_interface.value.id
      device_index         = tonumber(regex("[0-9]+" , network_interface.key))
    }
  }
}