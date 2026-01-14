variable "name" {
  description = "Name of the Virtual Network Gateway"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group Name"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Gateway (must be named GatewaySubnet)"
  type        = string
}

variable "sku" {
  description = "SKU of the VPN Gateway"
  type        = string
  default     = "VpnGw1"
}

variable "enable_bgp" {
  description = "Enable BGP"
  type        = bool
  default     = false
}

variable "asn" {
  description = "BGP ASN"
  type        = number
  default     = 65515
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
