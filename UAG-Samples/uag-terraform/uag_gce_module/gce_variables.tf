variable "uag_name" {
  description = "Base name for UAG instances"
  type        = string
}

variable "uag_count" {
  description = "Number of UAG instances to deploy"
  type        = number
}

variable "inputs" {
  description = "Path to the INI file with sensitive inputs"
  type        = string
}

variable "iniFile" {
  description = "Path to the INI file"
  type        = string
}