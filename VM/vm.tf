terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  subscription_id = "43dc09c0-4c1d-4496-9f2b-a8ee624aebff"
}

# Create a resource group
resource "azurerm_resource_group" "MyRG" {
  name     = "VM-RG"
  location = "France Central"
}

resource "azurerm_network_security_group" "my-nsg" {
  name                = "My_NSG"
  location            = azurerm_resource_group.MyRG.location
  resource_group_name = azurerm_resource_group.MyRG.name

   security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [
    azurerm_resource_group.MyRG 
  ]

}

resource "azurerm_virtual_network" "MyVNet" {
  name                = "MyVNet"
  location            = azurerm_resource_group.MyRG.location
  resource_group_name = azurerm_resource_group.MyRG.name
  address_space       = ["10.0.0.0/16"]
  
  depends_on = [
    azurerm_resource_group.MyRG
  ]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.MyRG.name
  virtual_network_name = azurerm_virtual_network.MyVNet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [
    azurerm_virtual_network.MyVNet
  ]
}

resource "azurerm_network_interface" "main" {
  name                = "mynetwork9521-nic"
  location            = azurerm_resource_group.MyRG.location
  resource_group_name = azurerm_resource_group.MyRG.name

  ip_configuration {
    name                          = "myconfiguration9521"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_resource_group.MyRG
  ]
}

resource "azurerm_network_interface_security_group_association" "associate" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.my-nsg.id

  depends_on = [
    azurerm_network_interface.main,
    azurerm_network_security_group.my-nsg,
  ]
}

resource "azurerm_virtual_machine" "VM" {
  name                  = "MyVM"
  location              = azurerm_resource_group.MyRG.location
  resource_group_name   = azurerm_resource_group.MyRG.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"
  # delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  storage_os_disk {
    name              = "MyDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "MyVM"
    admin_username = "himanshu"
    admin_password = "Him@nshu9521"
  }
  
  os_profile_windows_config {
    provision_vm_agent = false
    enable_automatic_upgrades = false

  }

  depends_on = [
    azurerm_network_interface_security_group_association.associate,
    azurerm_subnet.subnet,
  ]
}