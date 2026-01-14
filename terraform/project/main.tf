locals {
  resource_group_name  = "rg-${var.workload}-${var.environment_prefix}-${var.suffix}"
  actual_data_location = var.data_location != "" ? var.data_location : var.location
}

# Resource Group
module "resource_group" {
  source = "../modules/azurerm/resource_group"

  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network 1: App Gateway
module "virtual_network_appgw" {
  source = "../modules/azurerm/virtual_network"

  name                = "vnet-appgw-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = [var.appgw_vnet_address_space]
  tags                = var.tags
}

# Virtual Network 2: Backend (App Service)
module "virtual_network_backend" {
  source = "../modules/azurerm/virtual_network"

  name                = "vnet-backend-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = [var.backend_vnet_address_space]
  tags                = var.tags
}

# Subnets
module "subnet_appgw" {
  source = "../modules/azurerm/subnet"

  name                 = "snet-appgw"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network_appgw.name
  address_prefixes     = [var.appgw_subnet_address_prefix]
}

module "subnet_gateway_appgw" {
  source = "../modules/azurerm/subnet"

  name                 = "GatewaySubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network_appgw.name
  address_prefixes     = [var.appgw_gateway_subnet_address_prefix]
}

module "subnet_app_integration" {
  source = "../modules/azurerm/subnet"

  name                 = "snet-app-integration"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network_backend.name
  address_prefixes     = [var.app_subnet_address_prefix]
  
  delegation = {
    name = "delegation"
    service_delegation = {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

module "subnet_private_endpoints" {
  source = "../modules/azurerm/subnet"

  name                 = "snet-private-endpoints"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network_backend.name
  address_prefixes     = [var.pe_subnet_address_prefix]
}

module "subnet_gateway_backend" {
  source = "../modules/azurerm/subnet"

  name                 = "GatewaySubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network_backend.name
  address_prefixes     = [var.backend_gateway_subnet_address_prefix]
}

# VPN Gateways
module "vpn_gateway_appgw" {
  source = "../modules/azurerm/virtual_network_gateway"

  name                = "vpngw-appgw-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.subnet_gateway_appgw.id
  enable_bgp          = true
  asn                 = var.vpn_bgp_asn_appgw
  tags                = var.tags
}

module "vpn_gateway_backend" {
  source = "../modules/azurerm/virtual_network_gateway"

  name                = "vpngw-backend-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.subnet_gateway_backend.id
  enable_bgp          = true
  asn                 = var.vpn_bgp_asn_backend
  tags                = var.tags
}

# Shared Key for VPN
resource "random_password" "vpn_shared_key" {
  length  = 24
  special = true
}

# VPN Connections
resource "azurerm_virtual_network_gateway_connection" "appgw_to_backend" {
  name                = "conn-appgw-to-backend"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.vpn_gateway_appgw.id
  peer_virtual_network_gateway_id = module.vpn_gateway_backend.id

  shared_key = random_password.vpn_shared_key.result
  enable_bgp = true
  tags       = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "backend_to_appgw" {
  name                = "conn-backend-to-appgw"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.vpn_gateway_backend.id
  peer_virtual_network_gateway_id = module.vpn_gateway_appgw.id

  shared_key = random_password.vpn_shared_key.result
  enable_bgp = true
  tags       = var.tags
}

# Private DNS Zone for App Service (Linked to Backend VNet by default)
module "private_dns_app" {
  source = "../modules/azurerm/private_dns"

  name                = "privatelink.azurewebsites.net"
  resource_group_name = module.resource_group.name
  virtual_network_id  = module.virtual_network_backend.id
  tags                = var.tags
}

# Link Private DNS Zone to AppGw VNet
resource "azurerm_private_dns_zone_virtual_network_link" "appgw_link" {
  name                  = "link-appgw"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = module.private_dns_app.name
  virtual_network_id    = module.virtual_network_appgw.id
  tags                  = var.tags
}

# Private Endpoint for App Service
module "private_endpoint_app" {
  source = "../modules/azurerm/private_endpoint"

  name                           = "pe-app-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name            = module.resource_group.name
  location                       = module.resource_group.location
  subnet_id                      = module.subnet_private_endpoints.id
  private_connection_resource_id = module.app_service.id
  subresource_names              = ["sites"]
  private_dns_zone_ids           = [module.private_dns_app.id]
  tags                           = var.tags
}

# App Service
module "app_service" {
  source = "../modules/azurerm/app_service"

  name                       = "app-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  sku_name                   = var.app_service_sku
  virtual_network_subnet_id  = module.subnet_app_integration.id
  tags                       = var.tags
}

# Application Gateway
module "application_gateway" {
  source = "../modules/azurerm/application_gateway"

  name                     = "appgw-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  subnet_id                = module.subnet_appgw.id
  backend_fqdns            = [module.app_service.default_hostname]
  sku_name                 = var.appgw_sku_name
  sku_tier                 = var.appgw_sku_tier
  capacity                 = var.appgw_capacity
  ssl_certificate_data     = var.ssl_certificate_data
  ssl_certificate_password = var.ssl_certificate_password
  tags                     = var.tags
}

# Network Security Group for App Gateway
module "nsg_appgw" {
  source = "../modules/azurerm/network_security_group"

  name                = "nsg-appgw-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.subnet_appgw.id
  
  security_rules = [
    {
      name                       = "AllowGatewayManager"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowHTTP"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowHTTPS"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowAzureLoadBalancer"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
  ]
  
  tags = var.tags
}

# Network Security Group for App Service
module "nsg_app" {
  source = "../modules/azurerm/network_security_group"

  name                = "nsg-app-${var.workload}-${var.environment_prefix}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.subnet_app_integration.id
  
  security_rules = [
    {
      name                       = "AllowAppGatewayInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = var.appgw_subnet_address_prefix
      destination_address_prefix = var.app_subnet_address_prefix
    }
  ]
  
  tags = var.tags
}
