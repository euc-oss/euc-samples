module "admin_create" {
  source = "../../../common/admin/create"
  config_data = var.config_data
  api_endpoints = var.api_endpoints
  platform = var.platform
  operation = var.operation
  temp_dir = var.temp_dir
}

# Due to the limitation in the vsphere vm call, that verify an existing URL or local ova
# that is verified during plan, this is a workaround to fetch the url and download the build
# during plan phase.
data "external" "config" {
  program = ["python3", "${path.module}/../../../common/scripts/fetch_build.py"]
  query = {
    api_token_url = var.api_endpoints.api_token_url
    refresh_token = var.config_data.admin.refresh_token
    temp_dir = var.temp_dir
    ovf_api_url = var.api_endpoints.get_edge_config_url 
  }
}

output "output_provider" {
  value =  module.admin_create.output_provider
}

output "output_edge" {
  value =  module.admin_create.output_edge
}

output "download_ova_url" {
  value = module.admin_create.download_ova_url
}

locals {
  token = module.admin_create.new_token
  provider_id = module.admin_create.output_provider.id
  edge_id = module.admin_create.output_edge.id
  ova_url = module.admin_create.download_ova_url
}

data "vsphere_datacenter" "dc" {
  name = var.config_data.vsphere.datacenter
}

data "vsphere_datastore" "datastore" {
  name = var.config_data.vsphere.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name = var.config_data.vsphere.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name  = var.config_data.vsphere.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "resource_pool" {
  name = var.config_data.vsphere.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  name = var.config_data.vsphere.host
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  depends_on = [module.admin_create]
  name  = var.config_data.vsphere.vm.name
  datastore_id = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  host_system_id = data.vsphere_host.host.id
  datacenter_id = data.vsphere_datacenter.dc.id
  num_cpus = var.config_data.vsphere.vm.num_cpus
  memory = var.config_data.vsphere.vm.memory
  ovf_deploy {
    disk_provisioning = "thin"           
    local_ovf_path = data.external.config.result.ovf_path
    ovf_network_map = {
      "Network" = data.vsphere_network.network.id  
    }
  }
  network_interface {
    network_id = data.vsphere_network.network.id
    adapter_type = var.config_data.vsphere.adapter_type
  }
  vapp {
  properties = {
    "ipAddress" = var.config_data.vsphere.vm.ip_details.ipaddress,
    "netMask" = var.config_data.vsphere.vm.ip_details.netmask,
    "defaultGateway" = var.config_data.vsphere.vm.ip_details.gateway,
    "dns" = var.config_data.vsphere.vm.ip_details.dns,
    "domainName" = var.config_data.vsphere.vm.domain,
    "rootPassword" = var.config_data.vsphere.vm.credentials.root_password,
    "pairingCode" = module.admin_create.output_pairing_code.pairingCode
  }
  }
  lifecycle { 
    prevent_destroy = true
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
  depends_on = [resource.vsphere_virtual_machine.vm]
}

