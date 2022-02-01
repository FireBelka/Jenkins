terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

locals {
  env_variables_prod = {
    DOCKER_REGISTRY_SERVER_URL      = ...
    DOCKER_REGISTRY_SERVER_USERNAME = ...
    DOCKER_REGISTRY_SERVER_PASSWORD = ...
  }
  env_variables_staging = {
    DOCKER_REGISTRY_SERVER_URL      = ...
    DOCKER_REGISTRY_SERVER_USERNAME = ...
    DOCKER_REGISTRY_SERVER_PASSWORD = ...
  }
}

resource "azurerm_resource_group" "myterraformgroup" {
  name     = "Jenkins-test"
  location = "eastus"
}
resource "azurerm_resource_group" "web-rg" {
  name     = "web-rg"
  location = "eastus"
}
resource "azurerm_app_service_plan" "app-service-plan-1" {
  name                = "app-service-plan-1"
  location            = azurerm_resource_group.web-rg.location
  resource_group_name = azurerm_resource_group.web-rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Premiumv2"
    size = "P1v2"
  }

}
resource "azurerm_app_service" "web-app" {
  name                = "web-app-from-jenkins"
  location            = azurerm_resource_group.web-rg.location
  resource_group_name = azurerm_resource_group.web-rg.name
  app_service_plan_id = azurerm_app_service_plan.app-service-plan-1.id
  site_config {
    always_on        = "true"
    linux_fx_version = "DOCKER|testregk8s.azurecr.io/web-app:latest"
  }
  app_settings = local.env_variables_prod
}

resource "azurerm_app_service_slot" "web-app-staging" {
  name                = "staging"
  app_service_name    = azurerm_app_service.web-app.name
  location            = azurerm_resource_group.web-rg.location
  resource_group_name = azurerm_resource_group.web-rg.name
  app_service_plan_id = azurerm_app_service_plan.app-service-plan-1.id
  site_config {
    always_on        = "true"
    linux_fx_version = "DOCKER|testregk8s.azurecr.io/web-app:latest"

  }

  app_settings = local.env_variables_staging
}
# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet1" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs

resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "myPublicIP"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Terraform Demo"
  }
}





# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "NSG-web-1"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  security_rule {
    name                       = "Jenkins"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "SSH"
    priority                   = 937
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Http"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https_port"
    priority                   = 998
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Terraform Demo"
  }
}



# Create network interface
resource "azurerm_network_interface" "myterraformnic1" {
  name                = "myNIC1"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "web-ni-conf-1"
    subnet_id                     = azurerm_subnet.myterraformsubnet1.id
    private_ip_address            = "10.0.1.4"
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic1.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}



/*data "tls_public_key" "example_ssh" {
  private_key_pem = file("~/.ssh/id_rsa")
}
output "tls_private_key" {
  value = data.tls_public_key.example_ssh.public_key_openssh
}*/



# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm1" {
  name                  = "myVM1"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.myterraformnic1.id]
  size                  = "Standard_b1s"
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data                     = base64encode(file("init.sh"))
  computer_name                   = "myvm1"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}
