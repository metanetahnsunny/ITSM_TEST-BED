output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_ids" {
  value = {
    for k, v in azurerm_virtual_network.vnets : k => v.id
  }
}

output "vm_public_ips" {
  value = {
    for k, v in azurerm_public_ip.pip : k => v.ip_address
  }
}

output "vm_private_ips" {
  value = {
    for k, v in azurerm_network_interface.nic : k => v.private_ip_address
  }
} 