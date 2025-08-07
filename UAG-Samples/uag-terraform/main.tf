terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.0.2"
    }
    config = {
      source = "alabuel/config"
      version = "0.2.8"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Configure the vSphere Provider
provider "vsphere" {
  user                 = var.vSphere_user
  password             = var.vSphere_password
  vsphere_server       = var.vSphere_server
  allow_unverified_ssl = var.allow_unverified_ssl
}

# Configure the AWS Provider
provider "aws" {
  shared_config_files      = []
  shared_credentials_files = []
  profile                  = ""
  region = ""
}

# Configure the GCE Provider
provider "google" {
  project = ""
  credentials = ""
}

module "vsphere_template" {
  source    = "./uag_vsphere_module"
  uag_name  = "<uag_name>"
  uag_count = 1
  iniFile   = "uag.ini"
  inputs    = var.sensitive_input
}

module "aws_template" {
  source    = "./uag_aws_module"
  uag_name  = "<uag_name>"
  uag_count = 1
  iniFile   = "uag.ini"
  inputs    = var.sensitive_input
}

module "gce_template" {
  source    = "./uag_gce_module"
  uag_name  = "<uag_name>"
  uag_count = 1
  iniFile   = "uag.ini"
  inputs    = var.sensitive_input
}