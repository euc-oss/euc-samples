variable "platform" {
  type        = string
  description = "Enter the platform: azure"
  default = "vsphere"
}

variable "operation" {
  type        = string
  description = "Enter the operation: create"
  validation {
    condition     = contains(["create"], var.operation)
    error_message = "Error! Operation can only be 'create'."
  }
}

variable "config_file" {
  description = "Path of the configuration file"
  type        = string
  validation {
    condition     = var.config_file != "" && fileexists(var.config_file)
    error_message = "Error! Config_file path must not be empty and must be a valid JSON file."
  }
}

variable "api_endpoints" {
  type = any
}

variable "config_data" {
  type = any
  default = {}
  sensitive = true
}

variable "windows_temp_dir" {
  description = "Path to the windows temporary directory"
  type        = string
  default = "c:\\temp\\"
}

variable "linux_temp_dir" {
  description = "Path to the linux temporary directory"
  type        = string
  default = "/tmp/"
}