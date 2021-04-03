provider "azurerm" {
  features {}
}

locals {
  aks_cluster_name = "${var.prefix}-${var.environment}"
}

data "azurerm_subscription" "k8s_subcription" {
}

resource "azurerm_resource_group" "k8s_rg" {
  name     = "${local.aks_cluster_name}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "k8s_vnet" {
  name                = "${local.aks_cluster_name}-vnet"
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "k8s_subnet" {
  name                 = "${local.aks_cluster_name}-subnet"
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_log_analytics_workspace" "k8s_monitor" {
  name                = "${local.aks_cluster_name}-monitor"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_user_assigned_identity" "k8s_identity" {
  name                = local.aks_cluster_name
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
}

resource "azurerm_role_assignment" "k8s_role" {
  principal_id         = azurerm_user_assigned_identity.k8s_identity.principal_id
  scope                = data.azurerm_subscription.k8s_subcription.id
  role_definition_name = "Network Contributor"
}

resource "azurerm_kubernetes_cluster" "k8s_cluster" {
  name                = local.aks_cluster_name
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  dns_prefix          = local.aks_cluster_name

  default_node_pool {
    name                = "system"
    vm_size             = "Standard_B2ms"
    vnet_subnet_id      = azurerm_subnet.k8s_subnet.id
    node_count          = 3
    availability_zones  = [1, 2, 3]
  }

  network_profile {
    network_plugin     = "kubenet"
    load_balancer_sku  = "standard"
    docker_bridge_cidr = "172.17.0.1/16"
    pod_cidr           = "10.244.0.0/16"
    service_cidr       = "10.2.0.0/24"
    dns_service_ip     = "10.2.0.10"
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.k8s_identity.id
  }

  role_based_access_control {
    enabled = true
  }

  private_cluster_enabled = true

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = true
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = false
    }

    oms_agent {
      enabled                     = true
      log_analytics_workspace_id  = azurerm_log_analytics_workspace.k8s_monitor.id
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "k8s_nodepool_dev" {
  name                  = "elastic"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s_cluster.id
  vm_size               = "Standard_B2s"
  vnet_subnet_id        = azurerm_subnet.k8s_subnet.id
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 10
  availability_zones    = [1, 2, 3]
}
