terraform {
  # Use a recent version of Terraform
  required_version = ">= 0.13"

  # Map providers to thier sources, required in Terraform 13+
  required_providers {
    # Azure Resource Manager 2.x
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.44.0"
    }
    # Helm 2.x
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0.2 "
    }
    # Random 3.x
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Store terraform state with Azure Storage as backend
  backend "azurerm" {
    resource_group_name  = "saty-terraform-rg"
    storage_account_name = "satyterraformbackend"
    container_name       = "terraform-state"
    key                  = "public-aks.terraform.tfstate"
  }
}