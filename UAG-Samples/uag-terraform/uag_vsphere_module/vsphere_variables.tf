variable "uag_name" {
  description = "Create UAGs with following prefix. Number will be appended based on uag_count below"
  type        = string
  default     = "uag"
}

variable "uag_count" {
  description = "Number of UAG instances to be deployed"
  type        = number
  validation {
    condition = var.uag_count >= 0
    error_message = "Error: Number of UAG instances to be deployed cannot be negative"
  }
}

variable "iniFile" {
  description = "Configure UAG with ini file"
  type        = string
}

variable "inputs" {
  description = "Input file with sensitive data"
  type        = string
}
