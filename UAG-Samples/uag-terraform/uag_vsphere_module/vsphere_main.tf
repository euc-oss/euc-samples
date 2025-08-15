terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.0.2"
    }
    config = {
      source  = "alabuel/config"
      version = "0.2.8"
    }
  }
}

data "vsphere_datacenter" "datacenter" {
  name = lookup(data.external.config[0].result, "datacenter", "Cluster2")
  # name = data.external.config[0].result.datacenter == "" ? null : data.external.config[0].result.datacenter
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}

data "vsphere_datastore" "datastore" {
  name          = data.external.config[0].result.datastore == "" ? null : data.external.config[0].result.datastore
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}

data "vsphere_compute_cluster" "cluster" {
  name = data.external.config[0].result.cluster== "" ? null : data.external.config[0].result.cluster
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}

data "vsphere_resource_pool" "pool" {
  name          = data.external.config[0].result.pool == "" ? null : data.external.config[0].result.pool
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  #count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
  count =0
}

data "vsphere_network" "network0" {
  name          = data.external.config[0].result.network0 == "" ? null : data.external.config[0].result.network0
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? (data.external.config[0].result.network0 == "" ? 0 : 1) : 0
}

data "vsphere_network" "network1" {
  name          = data.external.config[0].result.network1 == "" ? null : data.external.config[0].result.network1
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? (data.external.config[0].result.network1 == "" ? 0 : 1) : 0
}

data "vsphere_network" "network2" {
  name          = data.external.config[0].result.network2 == "" ? null : data.external.config[0].result.network2
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? (data.external.config[0].result.network2 == "" ? 0 : 1) : 0
}

data "vsphere_host" "host" {
  name          = data.external.config[0].result.host == "" ? null : data.external.config[0].result.host
  datacenter_id = data.vsphere_datacenter.datacenter[0].id
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}


## Local OVF/OVA Source
data "vsphere_ovf_vm_template" "ovfLocal" {
  name  = "uag-terraform"
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
  disk_provisioning = data.external.config[0].result.diskMode != "" ? data.external.config[0].result.diskMode : "thin"
  resource_pool_id  = data.vsphere_compute_cluster.cluster[0].resource_pool_id
  datastore_id      = data.vsphere_datastore.datastore[0].id
  host_system_id    = data.vsphere_host.host[0].id
  allow_unverified_ssl_cert = data.external.config[0].result.allow_unverified_ssl_cert != "" ? data.external.config[0].result.allow_unverified_ssl_cert : true
  local_ovf_path    = local.ovf_source == "local" ? local.ovf_path : null
  remote_ovf_url    = local.ovf_source == "local" ? null : local.ovf_path
  ovf_network_map   = try(
    { "VM Network" : data.vsphere_network.network0[0].id
      "VM Network1" : data.vsphere_network.network1[0].id
      "VM Network2" : data.vsphere_network.network2[0].id
    },
    { "VM Network" : data.vsphere_network.network0[0].id
      "VM Network1" : data.vsphere_network.network1[0].id
    },
    { "VM Network" : data.vsphere_network.network0[0].id }
  )
}

data "external" "config" {
  program = ["pwsh", "uagdeploytr.ps1"]
  query = merge({for key,value in local.ini_map[local.name] : key => value}, { inifile = var.iniFile})
  count = (var.uag_count > 0 && fileexists(var.inputs)) ? 1 : 0
}

data "config_ini" "sensitive_ini" {
  ini = file(var.inputs)
}


locals {
  name = var.uag_name
  count = var.uag_count
  uagArray = {for i in range(1,local.count+1) : format("%s%d", local.name, i) => i }

  ini_map = jsondecode(data.config_ini.sensitive_ini.json)

  uagSize = length(data.external.config) > 0 ? (
    data.external.config[0].result.uagSize == "" ? "S" : data.external.config[0].result.uagSize) : "S"
  num_cpus = local.uagSize == "XL" ? 8 : (local.uagSize == "L" ? 4 : 2)
  memory = local.uagSize == "XL" ? 32768 : (local.uagSize == "L" ? 16384 : 4096)

  ovf_source = length(data.external.config) > 0 ? (
    data.external.config[0].result.ovf_source == "" ? "local" : data.external.config[0].result.ovf_source) : "local"
  ovf_path = length(data.external.config) > 0 ? (
    data.external.config[0].result.ovf_path == "" ? null : data.external.config[0].result.ovf_path) : null

#  raw_lines = fileexists(var.inputs) ? [
#  for line in split("\n", file(var.inputs)) :
#  split("=", trimspace(line))
#  ] : null
#
#  lines = local.raw_lines != null ? [
#  for line in local.raw_lines :
#  line if length(line[0]) > 0 && substr(line[0], 0, 1) != "#"
#  ] : null
#
#  params = local.raw_lines != null ? { for line in local.lines : trimspace(line[0]) => trimspace(line[1]) } : { }

  ip0 = length(data.external.config) > 0 ? data.external.config[0].result.ip0 : ""
  cidr_host0 = length(data.external.config) > 0 ? data.external.config[0].result.cidr0 : ""
  netmask0 = local.ip0 != "" ? data.external.config[0].result.maskLength0 : null
  address_range0 = local.ip0 != "" ? pow(2,32-local.netmask0) : null
  ip_addresses0 = local.ip0 != "" ? [for i in range(1, local.address_range0 -1): cidrhost(local.cidr_host0, i)] : null

  ip1 = length(data.external.config) > 0 ? data.external.config[0].result.ip1 : ""
  cidr_host1 = length(data.external.config) > 0 ? data.external.config[0].result.cidr1 : ""
  netmask1 = local.ip1 != "" ? data.external.config[0].result.maskLength1 : null
  address_range1 = local.ip1 != "" ? pow(2,32-local.netmask1) : null
  ip_addresses1 = local.ip1 != "" ? [for i in range(1, local.address_range1 -1): cidrhost(local.cidr_host1, i)] : null

  ip2 = length(data.external.config) > 0 ? data.external.config[0].result.ip2 : ""
  cidr_host2 = length(data.external.config) > 0 ? data.external.config[0].result.cidr2 : ""
  netmask2 = local.ip2 != "" ? data.external.config[0].result.maskLength2 : null
  address_range2 = local.ip2 != "" ? pow(2,32-local.netmask2) : null
  ip_addresses2 = local.ip2 != "" ? [for i in range(1, local.address_range2 -1): cidrhost(local.cidr_host2, i)] : null

  output = length(data.external.config) > 0 ? (
    data.external.config[0].result.warning != "" ? data.external.config[0].result.warning : null) : null

  hello = local.ini_map
}

## Deployment of VM from Local OVF
resource "vsphere_virtual_machine" "uag" {
  for_each = local.uagArray
  name = each.key
  resource_pool_id      = length(data.vsphere_compute_cluster.cluster) > 0 ? data.vsphere_compute_cluster.cluster[0].resource_pool_id : ""
  datastore_id          = length(data.vsphere_datastore.datastore) > 0 ? data.vsphere_datastore.datastore[0].id : null
  datacenter_id         = length(data.vsphere_datacenter.datacenter) > 0 ? data.vsphere_datacenter.datacenter[0].id : null
  host_system_id        = length(data.vsphere_host.host) > 0 ? data.vsphere_host.host[0].id : null
  num_cpus              = local.num_cpus
  num_cores_per_socket  = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].num_cores_per_socket : null
  memory                = local.memory
  guest_id              = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].guest_id : null
  nested_hv_enabled     = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].nested_hv_enabled : null
  dynamic "network_interface" {
    for_each = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].ovf_network_map : {}
    content {
      network_id = network_interface.value
    }
  }
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout = 0

  ovf_deploy {
    allow_unverified_ssl_cert = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].allow_unverified_ssl_cert : null
    local_ovf_path            = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? (local.ovf_source == "local" ? data.vsphere_ovf_vm_template.ovfLocal[0].local_ovf_path : null) : null
    remote_ovf_url            = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? (local.ovf_source == "local" ? null : data.vsphere_ovf_vm_template.ovfLocal[0].remote_ovf_url) : null
    disk_provisioning         = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].disk_provisioning: null
    ovf_network_map           = length(data.vsphere_ovf_vm_template.ovfLocal) > 0 ? data.vsphere_ovf_vm_template.ovfLocal[0].ovf_network_map : null
    enable_hidden_properties  = true
  }
  vapp {
    properties = length(data.external.config) > 0 ? {
      adminPassword = try(local.ini_map[local.name]["adminPassword"], null)
      rootPassword = try(local.ini_map[local.name]["rootPassword"], null)
      sshEnabled = data.external.config[0].result.sshEnabled == "" ? null : data.external.config[0].result.sshEnabled
      settingsJSON = sensitive(data.external.config[0].result.settings)
      uagName = each.key
      osLoginUsername = data.external.config[0].result.osLoginUsername == "root" ? null : data.external.config[0].result.osLoginUsername
      osMaxLoginLimit = data.external.config[0].result.osMaxLoginLimit == "" ? null : data.external.config[0].result.osMaxLoginLimit

      ip0 = local.ip0 == "" ? null : local.ip_addresses0[each.value]
      ipMode0 = data.external.config[0].result.ipMode0 == "" ? null : data.external.config[0].result.ipMode0
      netmask0 = data.external.config[0].result.netmask0 == "" ? null : data.external.config[0].result.netmask0
      routes0 = data.external.config[0].result.routes0 == "" ? null : data.external.config[0].result.routes0

      ip1 = local.ip1 == "" ? null : local.ip_addresses1[each.value]
      ipMode1 = data.external.config[0].result.ipMode1 == "" ? null : data.external.config[0].result.ipMode1
      netmask1 = data.external.config[0].result.netmask1 == "" ? null : data.external.config[0].result.netmask1
      routes1 = data.external.config[0].result.routes1 == "" ? null : data.external.config[0].result.routes1

      ip2 = local.ip2 == "" ? null : local.ip_addresses2[each.value]
      ipMode2 = data.external.config[0].result.ipMode2 == "" ? null : data.external.config[0].result.ipMode2
      netmask2 = data.external.config[0].result.netmask2 == "" ? null : data.external.config[0].result.netmask2
      routes2 = data.external.config[0].result.routes2 == "" ? null : data.external.config[0].result.routes2

      DNS = data.external.config[0].result.DNS == "" ? null : data.external.config[0].result.DNS
      rootPasswordExpirationDays = data.external.config[0].result.rootPasswordExpirationDays == "" ? null : data.external.config[0].result.rootPasswordExpirationDays
      passwordPolicyMinLen = data.external.config[0].result.passwordPolicyMinLen == "" ? null : data.external.config[0].result.passwordPolicyMinLen
      passwordPolicyMinClass = data.external.config[0].result.passwordPolicyMinClass == "" ? null : data.external.config[0].result.passwordPolicyMinClass
      passwordPolicyDifok = data.external.config[0].result.passwordPolicyDifok == "" ? null : data.external.config[0].result.passwordPolicyDifok
      passwordPolicyUnlockTime = data.external.config[0].result.passwordPolicyUnlockTime == "" ? null : data.external.config[0].result.passwordPolicyUnlockTime
      passwordPolicyFailedLockout = data.external.config[0].result.passwordPolicyFailedLockout == "" ? null : data.external.config[0].result.passwordPolicyFailedLockout
      adminPasswordPolicyFailedLockoutCount = data.external.config[0].result.adminPasswordPolicyFailedLockoutCount == "" ? null : data.external.config[0].result.adminPasswordPolicyFailedLockoutCount
      adminPasswordPolicyMinLen = data.external.config[0].result.adminPasswordPolicyMinLen == "" ? null : data.external.config[0].result.adminPasswordPolicyMinLen
      adminPasswordPolicyUnlockTime = data.external.config[0].result.adminPasswordPolicyUnlockTime == "" ? null : data.external.config[0].result.adminPasswordPolicyUnlockTime
      adminSessionIdleTimeoutMinutes = data.external.config[0].result.adminSessionIdleTimeoutMinutes == "" ? null : data.external.config[0].result.adminSessionIdleTimeoutMinutes
      adminMaxConcurrentSessions = data.external.config[0].result.adminMaxConcurrentSessions == "" ? null : data.external.config[0].result.adminMaxConcurrentSessions
      rootSessionIdleTimeoutSeconds = data.external.config[0].result.rootSessionIdleTimeoutSeconds == "" ? null : data.external.config[0].result.rootSessionIdleTimeoutSeconds
      commandsFirstBoot = data.external.config[0].result.commandsFirstBoot == "" ? null : data.external.config[0].result.commandsFirstBoot
      commandsEveryBoot = data.external.config[0].result.commandsEveryBoot == "" ? null : data.external.config[0].result.commandsEveryBoot
      defaultGateway = data.external.config[0].result.defaultGateway == "" ? null : data.external.config[0].result.defaultGateway
      v6DefaultGateway = data.external.config[0].result.v6DefaultGateway == "" ? null : data.external.config[0].result.v6DefaultGateway
      forwardrules = data.external.config[0].result.forwardrules == "" ? null : data.external.config[0].result.forwardrules
      routes0 = data.external.config[0].result.routes0 == "" ? null : data.external.config[0].result.routes0
      routes1 = data.external.config[0].result.routes1 == "" ? null : data.external.config[0].result.routes1
      routes2 = data.external.config[0].result.routes2 == "" ? null : data.external.config[0].result.routes2
      policyRouteGateway0 = data.external.config[0].result.policyRouteGateway0 == "" ? null : data.external.config[0].result.policyRouteGateway0
      policyRouteGateway1 = data.external.config[0].result.policyRouteGateway1 == "" ? null : data.external.config[0].result.policyRouteGateway1
      policyRouteGateway2 = data.external.config[0].result.policyRouteGateway2 == "" ? null : data.external.config[0].result.policyRouteGateway2

      sshLoginBannerText = data.external.config[0].result.sshLoginBannerText == "" ? null : data.external.config[0].result.sshLoginBannerText
      sshInterface = data.external.config[0].result.sshInterface == "" ? null : data.external.config[0].result.sshInterface
      secureRandomSource = data.external.config[0].result.secureRandomSource == "" ? null : data.external.config[0].result.secureRandomSource
      enabledAdvancedFeatures = data.external.config[0].result.enabledAdvancedFeatures == "" ? null : data.external.config[0].result.enabledAdvancedFeatures
      configURL = data.external.config[0].result.configURL == "" ? null : data.external.config[0].result.configURL
      configKey = data.external.config[0].result.configKey == "" ? null : data.external.config[0].result.configKey
      configURLHttpProxy = data.external.config[0].result.configURLHttpProxy == "" ? null : data.external.config[0].result.configURLHttpProxy
      adminCsrSubject = data.external.config[0].result.adminCsrSubject == "" ? null : data.external.config[0].result.adminCsrSubject
      adminCsrSAN = data.external.config[0].result.adminCsrSAN == "" ? null : data.external.config[0].result.adminCsrSAN
      additionalDeploymentMetadata = data.external.config[0].result.additionalDeploymentMetadata == "" ? null : data.external.config[0].result.additionalDeploymentMetadata

      ceipEnabled = data.external.config[0].result.ceipEnabled == "" ? null : data.external.config[0].result.ceipEnabled
      dsComplianceOS = data.external.config[0].result.dsComplianceOS == "" ? null : data.external.config[0].result.dsComplianceOS
      tlsPortSharingEnabled = data.external.config[0].result.tlsPortSharingEnabled == "" ? null : data.external.config[0].result.tlsPortSharingEnabled
      sshEnabled = data.external.config[0].result.sshEnabled == "" ? null : data.external.config[0].result.sshEnabled
      sshPasswordAccessEnabled = data.external.config[0].result.sshPasswordAccessEnabled == "" ? null : data.external.config[0].result.sshPasswordAccessEnabled
      sshKeyAccessEnabled = data.external.config[0].result.sshKeyAccessEnabled == "" ? null : data.external.config[0].result.sshKeyAccessEnabled
      sshPort = data.external.config[0].result.sshPort == "" ? null : data.external.config[0].result.sshPort
    } : { }
  }

  lifecycle {
    #    create_before_destroy = true
    ignore_changes = [
      vapp[0].properties,
      #ovf_deploy,
      network_interface,
      resource_pool_id,
      datastore_id,
      datacenter_id,
      host_system_id,
      num_cpus,
      num_cores_per_socket,
      memory,
      guest_id,
      nested_hv_enabled,

    ]
  }
}

output "uag_ipaddress" {
  value = values(vsphere_virtual_machine.uag)[*].default_ip_address
}

output "count" {
  value = length(vsphere_virtual_machine.uag)
}

output "output_message" {
  value = local.output
}

output "inimap" {
  value = local.ini_map[local.name]
}

output "datacenter_name" {
  value = lookup(data.external.config[0].result, "datacenter", "Cluster2")
}