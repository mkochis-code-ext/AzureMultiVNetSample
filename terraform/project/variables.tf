variable "environment_prefix" {
  description = "Environment prefix"
  type        = string
}

variable "suffix" {
  description = "Random suffix for uniqueness"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "workload" {
  description = "Workload name"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "data_location" {
  description = "Azure region for data resources"
  type        = string
}

variable "appgw_vnet_address_space" {
  description = "Address space for the Application Gateway virtual network"
  type        = string
}

variable "backend_vnet_address_space" {
  description = "Address space for the Backend virtual network"
  type        = string
}

variable "app_subnet_address_prefix" {
  description = "Address prefix for App Service integration subnet"
  type        = string
}

variable "appgw_subnet_address_prefix" {
  description = "Address prefix for Application Gateway subnet"
  type        = string
}

variable "pe_subnet_address_prefix" {
  description = "Address prefix for Private Endpoints subnet"
  type        = string
}

variable "appgw_gateway_subnet_address_prefix" {
  description = "Address prefix for AppGw VNet Gateway subnet"
  type        = string
}

variable "backend_gateway_subnet_address_prefix" {
  description = "Address prefix for Backend VNet Gateway subnet"
  type        = string
}

variable "vpn_bgp_asn_appgw" {
  description = "BGP ASN for AppGw VNet Gateway"
  type        = number
  default     = 65515
}

variable "vpn_bgp_asn_backend" {
  description = "BGP ASN for Backend VNet Gateway"
  type        = number
  default     = 65516
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string
}

variable "appgw_sku_name" {
  description = "SKU name for Application Gateway"
  type        = string
}

variable "appgw_sku_tier" {
  description = "SKU tier for Application Gateway"
  type        = string
}

variable "appgw_capacity" {
  description = "Capacity for Application Gateway"
  type        = number
}

variable "ssl_certificate_data" {
  description = "Base64 encoded SSL certificate data"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "SSL certificate password"
  type        = string
  sensitive   = true
}
