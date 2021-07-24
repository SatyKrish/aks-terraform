provider "azurerm" {
  features {}
}

locals {
  aks_cluster_name = lower("${var.prefix}-${var.environment}")
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "k8s_subcription" {}

resource "azurerm_resource_group" "k8s_rg" {
  name     = "${local.aks_cluster_name}-rg"
  location = var.location
  tags     = { environment = "var.environment" }
}

# Azure Container Registry Configuration
resource "azurerm_container_registry" "k8s_acr" {
  name                = "${var.prefix}${var.environment}acr"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  sku                 = "Basic"
  tags                = { environment = "var.environment" }
}

# Azure Virtual Network Configuration
resource "azurerm_virtual_network" "k8s_vnet" {
  name                = "${local.aks_cluster_name}-vnet"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  address_space       = ["10.1.0.0/20"]
  tags                = { environment = "var.environment" }
}

resource "azurerm_subnet" "k8s_subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_subnet" "k8s_subnet2" {
  name                 = "subnet2"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.1.4.0/22"]
}

resource "azurerm_subnet" "k8s_subnet3" {
  name                 = "subnet3"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.1.8.0/22"]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "bastion-subnet"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.1.12.0/28"]
}

resource "azurerm_public_ip" "bastion_ip" {
  name                = "${local.aks_cluster_name}-bastion-ip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { environment = "var.environment" }
}

resource "azurerm_bastion_host" "bastion_host" {
  name                = "${local.aks_cluster_name}-bastion"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }

  tags                = { environment = "var.environment" }
}

# Azure Monitoring Configuration
resource "azurerm_log_analytics_workspace" "k8s_monitor" {
  name                = "${local.aks_cluster_name}-monitor"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = { environment = "var.environment" }
}

resource "azurerm_application_insights" "k8s_insights" {
  name                = "${local.aks_cluster_name}-insights"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  application_type    = "web"
  retention_in_days   = 30
  tags                = { environment = "development" }
}

# Azure User Assigned Identities Configuration
resource "azurerm_user_assigned_identity" "k8s_identity" {
  name                = "${local.aks_cluster_name}-cluster-identity"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  tags                = { environment = "var.environment" }
}

resource "azurerm_role_assignment" "k8s_identity_role" {
  principal_id         = azurerm_user_assigned_identity.k8s_identity.principal_id
  scope                = data.azurerm_subscription.k8s_subcription.id
  role_definition_name = "Network Contributor"
}

resource "azurerm_user_assigned_identity" "k8s_kubelet_identity" {
  name                = "${local.aks_cluster_name}-kubelet-identity"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  tags                = { environment = "var.environment" }
}

resource "azurerm_role_assignment" "k8s_kubelete_identity_role" {
  principal_id         = azurerm_user_assigned_identity.k8s_identity.principal_id
  scope                = azurerm_container_registry.k8s_acr.id
  role_definition_name = "ACRPull"
}

# Azure Customer Managed Key Configuration
resource "azurerm_key_vault" "k8s_kv" {
  name                        = "${local.aks_cluster_name}-kv"
  location                    = azurerm_resource_group.k8s_rg.location
  resource_group_name         = azurerm_resource_group.k8s_rg.name
  tenant_id                   = data.azurerm_subscription.k8s_subcription.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  tags                        = { environment = "var.environment" }
}

resource "azurerm_key_vault_key" "k8s_kv_key" {
  name         = "${local.aks_cluster_name}-kv-key"
  key_vault_id = azurerm_key_vault.k8s_kv.id
  key_type     = "RSA"
  key_size     = 2048

  depends_on = [
    azurerm_key_vault_access_policy.k8s-admin-access
  ]

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

resource "azurerm_disk_encryption_set" "k8s-des" {
  name                = "${local.aks_cluster_name}-des"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  key_vault_key_id    = azurerm_key_vault.k8s_kv.id

  identity {
    type = "SystemAssigned"
  }

  tags                = { environment = "var.environment" }
}

resource "azurerm_key_vault_access_policy" "k8s-disk-access" {
  key_vault_id  = azurerm_key_vault.k8s_kv.id
  tenant_id     = azurerm_disk_encryption_set.k8s-des.identity.0.tenant_id
  object_id     = azurerm_disk_encryption_set.k8s-des.identity.0.principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
}

resource "azurerm_key_vault_access_policy" "k8s-admin-access" {
  key_vault_id = azurerm_key_vault.k8s_kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "get",
    "create",
    "delete"
  ]
}

# Azure Kubernetes Service Configuration
resource "azurerm_kubernetes_cluster" "k8s_cluster" {
  name                = local.aks_cluster_name
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  dns_prefix          = local.aks_cluster_name

  default_node_pool {
    name                = "system"
    vm_size             = "Standard_D2sv3"
    vnet_subnet_id      = azurerm_subnet.k8s_subnet1.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 10
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

  disk_encryption_set_id = azurerm_disk_encryption_set.k8s-des.id

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.k8s_identity.id
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.k8s_kubelet_identity.client_id
    object_id                 = azurerm_user_assigned_identity.k8s_kubelet_identity.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.k8s_kubelet_identity.id
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

  tags                = { environment = "var.environment" }
}

resource "azurerm_kubernetes_cluster_node_pool" "k8s_nodepool_dev" {
  name                  = "app"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s_cluster.id
  vm_size               = "Standard_B2s"
  vnet_subnet_id        = azurerm_subnet.k8s_subnet1.id
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 10
  availability_zones    = [1, 2, 3]
}
