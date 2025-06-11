terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 변수 정의
variable "resource_group_name" {
  type    = string
  default = "rg-testbed"
}

variable "location" {
  type    = string
  default = "koreacentral"
}

variable "vnet_address_spaces" {
  type = map(string)
  default = {
    vnet1 = "10.1.0.0/16"
    vnet2 = "10.2.0.0/16"
    vnet3 = "10.3.0.0/16"
  }
}

variable "subnet_prefix" {
  type    = string
  default = "24"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

# 리소스 그룹
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# VNet 및 서브넷
resource "azurerm_virtual_network" "vnets" {
  for_each            = var.vnet_address_spaces
  name                = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [each.value]
}

resource "azurerm_subnet" "subnets" {
  for_each             = var.vnet_address_spaces
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = each.key
  address_prefixes     = [cidrsubnet(each.value, 8, 0)]
}

# 관리 서브넷 추가 (vnet1에만)
resource "azurerm_subnet" "mgmt_subnet" {
  name                 = "subnet-mgmt"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = "vnet1"
  address_prefixes     = ["10.1.1.0/24"]
}

# VNet 피어링
resource "azurerm_virtual_network_peering" "peering" {
  for_each                     = {
    "vnet1-to-vnet2" = { source = "vnet1", remote = "vnet2" }
    "vnet2-to-vnet1" = { source = "vnet2", remote = "vnet1" }
    "vnet1-to-vnet3" = { source = "vnet1", remote = "vnet3" }
    "vnet3-to-vnet1" = { source = "vnet3", remote = "vnet1" }
    "vnet2-to-vnet3" = { source = "vnet2", remote = "vnet3" }
    "vnet3-to-vnet2" = { source = "vnet3", remote = "vnet2" }
  }
  name                         = each.key
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = each.value.source
  remote_virtual_network_id    = azurerm_virtual_network.vnets[each.value.remote].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  depends_on                   = [azurerm_virtual_network.vnets]
}

# 네트워크 보안 그룹
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.vnet_address_spaces
  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 서브넷과 NSG 연결
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each                  = var.vnet_address_spaces
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  depends_on               = [azurerm_subnet.subnets, azurerm_network_security_group.nsg]
}

# 퍼블릭 IP (기존 VM용)
resource "azurerm_public_ip" "pip" {
  for_each            = var.vnet_address_spaces
  name                = "pip-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# 퍼블릭 IP (monitoring VM용)
resource "azurerm_public_ip" "monitoring_pip" {
  for_each            = var.vnet_address_spaces
  name                = "pip-monitoring-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# 퍼블릭 IP (관리 VM용)
resource "azurerm_public_ip" "mgmt_pip" {
  name                = "pip-mgmt"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# 네트워크 인터페이스 (기존 VM용)
resource "azurerm_network_interface" "nic" {
  for_each            = var.vnet_address_spaces
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
  depends_on = [azurerm_subnet.subnets, azurerm_public_ip.pip]
}

# 네트워크 인터페이스 (monitoring VM용)
resource "azurerm_network_interface" "monitoring_nic" {
  for_each            = var.vnet_address_spaces
  name                = "nic-monitoring-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitoring_pip[each.key].id
  }
  depends_on = [azurerm_subnet.subnets, azurerm_public_ip.monitoring_pip]
}

# 네트워크 인터페이스 (관리 VM용)
resource "azurerm_network_interface" "mgmt_nic" {
  name                = "nic-mgmt"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mgmt_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt_pip.id
  }
  depends_on = [azurerm_subnet.mgmt_subnet, azurerm_public_ip.mgmt_pip]
}

# 가상 머신 (기존 VM)
resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = var.vnet_address_spaces
  name                = "vm-${each.key}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.nic, tls_private_key.ssh_key]
}

# 가상 머신 (monitoring VM)
resource "azurerm_linux_virtual_machine" "monitoring_vm" {
  for_each            = var.vnet_address_spaces
  name                = "monitoring-vm-${each.key}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.monitoring_nic[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.monitoring_nic, tls_private_key.ssh_key]
}

# 가상 머신 (관리 VM)
resource "azurerm_linux_virtual_machine" "mgmt_vm" {
  name                = "mgmt-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2s_v2"  # 2 vCPU, 4GB RAM
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.mgmt_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.mgmt_nic, tls_private_key.ssh_key]
}

# SSH 키 생성
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# SSH 키 파일로 저장
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh_key.pem"
  file_permission = "0600"
  depends_on      = [tls_private_key.ssh_key]
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${path.module}/ssh_key.pub"
  file_permission = "0644"
  depends_on      = [tls_private_key.ssh_key]
} 