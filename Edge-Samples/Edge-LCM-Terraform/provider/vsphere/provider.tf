terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.0.2"
    }
  }
}
