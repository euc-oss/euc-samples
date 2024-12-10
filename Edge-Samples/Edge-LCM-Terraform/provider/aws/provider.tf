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
    azurerm = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
