output "id" {
  value = azurerm_virtual_network_gateway.main.id
}

output "name" {
  value = azurerm_virtual_network_gateway.main.name
}

output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}

output "bgp_settings" {
  value = azurerm_virtual_network_gateway.main.bgp_settings
}
