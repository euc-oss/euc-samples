terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    config = {
      source  = "alabuel/config"
      version = "0.2.8"
    }
  }
}

data "external" "config" {
  program = ["pwsh", "./GCE_Preparation.ps1"]
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

locals {
  max_nics = 3
  nic_configs = [
    for i in range(0, local.max_nics) : {
      index      = i
      subnet     = lookup(data.external.config[0].result, "subnet${i}", null)
      public_ip  = lookup(data.external.config[0].result, format("publicIPAddress%d", i), null)
      private_ip = lookup(data.external.config[0].result, format("privateIPAddress%d", i), null)
    }
    if lookup(data.external.config[0].result, "subnet${i}", null) != null &&
    lookup(data.external.config[0].result, "subnet${i}", "") != ""
  ]
}

resource "google_compute_instance" "uag-gce" {
  for_each = local.uagArray
  name         = each.key
  machine_type = data.external.config[0].result.machineType
  zone         = data.external.config[0].result.zone

  boot_disk {
    initialize_params {
      image = data.external.config[0].result.imageName
    }
  }

  dynamic "network_interface" {
    for_each = local.nic_configs
    content {
      subnetwork = network_interface.value.subnet
      network_ip = network_interface.value.private_ip
      access_config {
        nat_ip = network_interface.value.public_ip
      }
    }
  }

  metadata = { "user-data" = data.external.config[0].result.userData }

  tags = lookup(data.external.config[0].result, "tags", null) != null ? split(",", data.external.config[0].result.tags) : []

  labels = lookup(data.external.config[0].result, "labels", null) != null ? tomap({ for label in split(",", data.external.config[0].result.labels) : label => "" }) : {}
}
