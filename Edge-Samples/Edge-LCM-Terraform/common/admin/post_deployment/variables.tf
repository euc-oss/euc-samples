
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

variable "edge_id" {
  description = "Edge id"
  type = string
}

variable "token" {
  description = "token"
  type  = string
  sensitive = true
}
variable "provider_id" {
  description = "Provider id"
  type  = string
  sensitive = true
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