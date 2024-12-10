# entry point for edge creation/upgrade
locals {
  is_windows = false
  temp_dir = var.linux_temp_dir
}

locals {
  config_data = jsondecode(file(var.config_file))
  platform = "ec2"
}
# To be developed

