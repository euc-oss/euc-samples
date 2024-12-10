
variable "config_data"  {
  description = "configuration data"
  type = any
  sensitive = true
}

variable "api_endpoints" {
  description = "api api_endpoints"
  type = map(any)
}

variable "platform" {
  type = string
  description = "provider platform : azure/vsphere/aws/..."  
}

variable "operation" {
  type = string
  description = "Operation that is being performed create/delete/upgrade"
}

variable "temp_dir" {
  description = "Path to the temporary directory"
  type = string
}