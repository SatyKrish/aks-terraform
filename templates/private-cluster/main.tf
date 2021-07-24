terraform {
  # Use a recent version of Terraform
  required_version = "~> 1.0.3"

  # Map providers to thier sources, required in Terraform 13+
  required_providers {
    # Azure Resource Manager 2.x
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.69.0"
    }
    # Helm 2.x
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.2.0"
    }
    # Random 3.x
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }

  # Store terraform state with Azure Storage as backend
  backend "azurerm" {
    resource_group_name  = "saty-terraform-rg"
    storage_account_name = "satyterraformbackend"
    container_name       = "terraform-state"
    key                  = "elastic-dev.terraform.tfstate"
  }
}