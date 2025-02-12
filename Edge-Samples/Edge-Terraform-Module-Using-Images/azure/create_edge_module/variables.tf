variable "platform" {
  type        = string
  description = "Enter the platform: azure"
  default = "azure"
}
variable "operation" {
  type        = string
  description = "Enter the operation: create"
  default     = "create"
   
}
variable "poll_iterations" {
  description = "Number of polling iterations"
  type = number
  default = 12
}

variable "wait_time" {
  description = "Wait time before every poll in seconds"
  type = number
  default = 150
}

variable "admin_refresh_token" {
  description = "Refresh token to be manually obtained from https://developer.omnissa.com/horizon-apis/horizon-cloud-nextgen/#what-is-the-horizon-cloud-service-next-gen"
  type        = string
  sensitive = true
}

variable "provider_name" {
  description = "Name of the provider instance that will be created"
  type        = string
}

variable "provider_type" {
  description = "Type of the provider"
  type        = string
  default = "AZURE"
}

variable "is_federated" {
  description = "Is this a federated edge. Refer to the Product documentation"
  type        = string
  default = "true"
}

variable "org_id" {
  description = "Org Id of the account"
  type        = string
}

variable "edge_name" {
  description = "Name of the edge to be created."
  type        = string
}

variable "edge_fqdn" {
  description = "FQDN of the edge"
  type        = string
}

variable "city" {
  description = "Location of the Deployment - City"
  type        = string
}

variable "state" {
  description = "Location of the Deployment - State"
  type        = string
}

variable "country" {
  description = "Location of the Deployment - Country"
  type        = string
}

variable "connection_server_url" {
  description = "URL of the connection server"
  type        = string
}

variable "connection_server_username" {
  description = "Admin user name of the connection server"
  type        = string
}

variable "connection_server_password" {
  description = "Password of the connection server"
  type        = string
  sensitive = true
}

variable "connection_server_domain" {
  description = "Connection Server domain"
  type        = string
}

variable "azure_region" {
  description = "Azure reqion to work on"
  type        = string
}

variable "azure_virtual_network" {
  description = "Name of the Azure virtual network to be used"
  type        = string
}

variable "azure_subnet" {
  description = "Name of the subnet to use"
  type        = string
}

variable "azure_network_resource_group" {
  description = "Name of the network resource group to be used"
  type        = string
}

variable "azure_image_name" {
  description = "Azure image name in compute gallery"
  type        = string
}

variable "azure_image_gallery_name" {
  description = "Image gallery name"
  type        = string
}

variable "azure_image_resource_group" {
  description = "Image resource group"
  type        = string
}

variable "azure_image_version" {
  description = "Image version"
  type        = string
}

variable "vm_admin_username" {
  description = "Edge VM user name"
  type        = string
  default = "ccadmin"
}

variable "vm_admin_password" {
  description = "Admin password for the edge vm"
  type        = string
  sensitive = true
}

variable "vm_managed_disk_type" {
  description = "Type of the managed disk. eg Standard_LRS."
  type        = string
}

variable "vm_resource_group" {
  description = "Name of the resource group where the edge vm will be created."
  type        = string
}

variable "vm_size" {
  description = "VM sizing for the Edge vM"
  type        = string
}

variable "static_ip_address" {
  description = "Static ip address of the Edge VM"
  type        = string
}

variable api_endpoints {
  description = "API end points. Please do not update."
  default = {
    api_token_url = "https://connect.omnissa.com/csp/gateway/am/api/auth/api-tokens/authorize"
    create_provider_url = "https://cloud-sg.horizon.omnissa.com/admin/v3/providers/instances?ignore_warnings=false"
    create_edge_url = "https://cloud-sg.horizon.omnissa.com/admin/v2/edge-deployments"
    pairing_code_url_suffix = "device-pairing-info"
    get_edge_config_url = "https://cloud-sg.horizon.omnissa.com/admin/v3/providers/edge-download-configs?label=view"
    cs_configure_url = "https://cloud-sg.horizon.omnissa.com/admin/v3/providers/instances"
    provider_url = "https://cloud-sg.horizon.omnissa.com/admin/v3/providers/instances?include_health_details=false"
  }

}