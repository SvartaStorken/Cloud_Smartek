# Konfigurera Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.117.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Skapa en NY resursgrupp
resource "azurerm_resource_group" "rg" {
  name     = "terraform-smartek"
  location = "swedencentral"
}

# 2. Skapa ett NYTT virtuellt nätverk
resource "azurerm_virtual_network" "vnet" {
  name                = "smartek-Terraform-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Skapa ett NYTT subnät
resource "azurerm_subnet" "vm_subnet" {
  name                 = "terraform-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

# --- NGINX VM Resurser ---

# 4. Publik IP-adress för Nginx VM
resource "azurerm_public_ip" "nginx_pub_ip" { # Omdöpt för tydlighet
  name                = "terraform-nginx-pub-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Nätverkskort (NIC) för Nginx VM
resource "azurerm_network_interface" "nginx_nic" { # Omdöpt för tydlighet
  name                = "terraform-nginx-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nginx_pub_ip.id # Kopplad till Nginx publik IP
  }
  depends_on = [
    azurerm_subnet.vm_subnet,
    azurerm_public_ip.nginx_pub_ip
  ]
}

# 6. Nätverkssäkerhetsgrupp (NSG) för Nginx VM
resource "azurerm_network_security_group" "nginx_nsg" { # Omdöpt för tydlighet
  name                = "terraform-nginx-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # För produktion, begränsa till din IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "SSH-Mariadb"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "SSH-Wordpress"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "SSH-Mongodb"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "SSH-MinIO"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule { 
    name                       = "SQL-Mariadb"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Test"
    project     = "NewRGTest-Nginx"
  }
}

# Koppla NSG till Nginx NIC
resource "azurerm_network_interface_security_group_association" "nginx_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nginx_nic.id
  network_security_group_id = azurerm_network_security_group.nginx_nsg.id
}

# 7. Virtuell maskin för Nginx
resource "azurerm_linux_virtual_machine" "terraform-nginxvm" { # Lokalt Terraform-namn
  name                  = "terraform-vm-nginxvm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nginx_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMVO35cdysO5/MQALiI4xx2ZUHM33hYOVbEAOmjBWXDIgZUde7LEkLmW4lhbdXtSRxzBxbPrjzdHTUgYzcVDeVi2PPBgHtaTiNJgi6vTPRyOErqyBg8qrncRW2dNipJErUZ5+S9XQzwiOsSgXl4o465n3O+N5YuiFQhSWlSsDcesIdXkxiJFYTDdeW5whZ1SBzNLUKZveBsPRd3qGmYc+qsnGvfP2etbDX/J0TJcMwYeH1Z6O1RahXdoytxvzcRVS59UqB03XkbYF6nzreRzzkyQKkPTi3WG+/dK8lqrECYBDA0fqFXCC8e9e2dSveJKn3tDQC9zAAu+p/7b3a4NWQrrydNoPMPef18N6TNwNn9ftp6KTEvZxPMAlatvHrnE7+jppVJWoLU3f4tU2FgrcY+7zWpD+ueYGD3eelhjhkSvYFcsy4eH3W5GjbMhdk0bUGli9KYDQFMINRsFhfuy6YidVj2ImK/wBshNNiZE7B8wWOxuJEukQng2m/Xm3Wr7X4ub9zhxyL1UrRmCB2Ca0cwafgybnHrYogtudtViozfjvYliga/L13WR1n5rnjVW9zbZw/BlVgUYqTB6d65rkLV4keWkrx8oJqyfX1YnHuTPeDyV40i0PWljg/yN1FqtF17c2NBcd91ol/o7pHvgL1gWdxJFiZRdHpAjPECYWQbw== martin.wallin@lerniastudent.se"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference { 
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts-daily"
    sku       = "server-gen1"
    version   = "latest"
  }

  tags = {
    environment = "Test"
    createdBy   = "Terraform"
    project     = "NewRGTest-Nginx"
    role        = "nginx"
  }
}

# --- MARIADB VM Resurser ---

# 8. Nätverkskort (NIC) för MariaDB VM (ingen publik IP)
resource "azurerm_network_interface" "mariadb_nic" {
  name                = "terraform-mariadb-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    # Ingen public_ip_address_id
  }
  depends_on = [
    azurerm_subnet.vm_subnet
  ]
}

# 9. Nätverkssäkerhetsgrupp (NSG) för MariaDB VM
resource "azurerm_network_security_group" "mariadb_nsg" {
  name                = "terraform-mariadb-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH_From_Nginx"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt SSH från Nginx privata IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MariaDB_From_Nginx"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306" # Standardport för MariaDB/MySQL
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt MariaDB-trafik från Nginx privata IP
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Test"
    project     = "NewRGTest-MariaDB"
  }
}

# Koppla NSG till MariaDB NIC
resource "azurerm_network_interface_security_group_association" "mariadb_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.mariadb_nic.id
  network_security_group_id = azurerm_network_security_group.mariadb_nsg.id
}

# 10. Virtuell maskin för MariaDB
resource "azurerm_linux_virtual_machine" "mariadb_vm" { # Nytt lokalt Terraform-namn
  name                  = "terraform-vm-mariadb"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_DS1_v2" # Kan vara mindre om det bara är DB
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.mariadb_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMVO35cdysO5/MQALiI4xx2ZUHM33hYOVbEAOmjBWXDIgZUde7LEkLmW4lhbdXtSRxzBxbPrjzdHTUgYzcVDeVi2PPBgHtaTiNJgi6vTPRyOErqyBg8qrncRW2dNipJErUZ5+S9XQzwiOsSgXl4o465n3O+N5YuiFQhSWlSsDcesIdXkxiJFYTDdeW5whZ1SBzNLUKZveBsPRd3qGmYc+qsnGvfP2etbDX/J0TJcMwYeH1Z6O1RahXdoytxvzcRVS59UqB03XkbYF6nzreRzzkyQKkPTi3WG+/dK8lqrECYBDA0fqFXCC8e9e2dSveJKn3tDQC9zAAu+p/7b3a4NWQrrydNoPMPef18N6TNwNn9ftp6KTEvZxPMAlatvHrnE7+jppVJWoLU3f4tU2FgrcY+7zWpD+ueYGD3eelhjhkSvYFcsy4eH3W5GjbMhdk0bUGli9KYDQFMINRsFhfuy6YidVj2ImK/wBshNNiZE7B8wWOxuJEukQng2m/Xm3Wr7X4ub9zhxyL1UrRmCB2Ca0cwafgybnHrYogtudtViozfjvYliga/L13WR1n5rnjVW9zbZw/BlVgUYqTB6d65rkLV4keWkrx8oJqyfX1YnHuTPeDyV40i0PWljg/yN1FqtF17c2NBcd91ol/o7pHvgL1gWdxJFiZRdHpAjPECYWQbw== martin.wallin@lerniastudent.se"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference { 
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts-daily"
    sku       = "server-gen1"
    version   = "latest"
  }

  tags = {
    environment = "Test"
    createdBy   = "Terraform"
    project     = "NewRGTest-MariaDB"
    role        = "mariadb"
  }
}

# --- Wordpress VM Resurser ---

# 11. Nätverkskort (NIC) för Wordpress VM (ingen publik IP)
resource "azurerm_network_interface" "wordpress_nic" {
  name                = "terraform-Wordpress-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    # Ingen public_ip_address_id här
  }
  depends_on = [
    azurerm_subnet.vm_subnet
  ]
}

# 12. Nätverkssäkerhetsgrupp (NSG) för Wordpress VM
resource "azurerm_network_security_group" "wordpress_nsg" {
  name                = "terraform-Wordpress-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH_From_Nginx"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt SSH från Nginx privata IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP_From_Nginx"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80" 
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt Wordpress-trafik från Nginx privata IP
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Test"
    project     = "NewRGTest-Wordpress"
  }
}

# Koppla NSG till Wordpress NIC
resource "azurerm_network_interface_security_group_association" "wordpress_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.wordpress_nic.id
  network_security_group_id = azurerm_network_security_group.wordpress_nsg.id
}

# 13. Virtuell maskin för Wordpress
resource "azurerm_linux_virtual_machine" "terraform-wordpress_vm" { # Nytt lokalt Terraform-namn
  name                  = "terraform-vm-wordpress"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_DS1_v2" 
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.wordpress_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMVO35cdysO5/MQALiI4xx2ZUHM33hYOVbEAOmjBWXDIgZUde7LEkLmW4lhbdXtSRxzBxbPrjzdHTUgYzcVDeVi2PPBgHtaTiNJgi6vTPRyOErqyBg8qrncRW2dNipJErUZ5+S9XQzwiOsSgXl4o465n3O+N5YuiFQhSWlSsDcesIdXkxiJFYTDdeW5whZ1SBzNLUKZveBsPRd3qGmYc+qsnGvfP2etbDX/J0TJcMwYeH1Z6O1RahXdoytxvzcRVS59UqB03XkbYF6nzreRzzkyQKkPTi3WG+/dK8lqrECYBDA0fqFXCC8e9e2dSveJKn3tDQC9zAAu+p/7b3a4NWQrrydNoPMPef18N6TNwNn9ftp6KTEvZxPMAlatvHrnE7+jppVJWoLU3f4tU2FgrcY+7zWpD+ueYGD3eelhjhkSvYFcsy4eH3W5GjbMhdk0bUGli9KYDQFMINRsFhfuy6YidVj2ImK/wBshNNiZE7B8wWOxuJEukQng2m/Xm3Wr7X4ub9zhxyL1UrRmCB2Ca0cwafgybnHrYogtudtViozfjvYliga/L13WR1n5rnjVW9zbZw/BlVgUYqTB6d65rkLV4keWkrx8oJqyfX1YnHuTPeDyV40i0PWljg/yN1FqtF17c2NBcd91ol/o7pHvgL1gWdxJFiZRdHpAjPECYWQbw== martin.wallin@lerniastudent.se"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference { 
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts-daily"
    sku       = "server-gen1"
    version   = "latest"
  }

  tags = {
    environment = "Test"
    createdBy   = "Terraform"
    project     = "NewRGTest-Wordpress"
    role        = "wordpress"
  }
}

# --- Mongodb VM Resurser ---

# 14. Nätverkskort (NIC) för Mongodb VM (ingen publik IP)
resource "azurerm_network_interface" "mongodb_nic" {
  name                = "terraform-mongodb-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    # Ingen public_ip_address_id här
  }
  depends_on = [
    azurerm_subnet.vm_subnet
  ]
}

# 15. Nätverkssäkerhetsgrupp (NSG) för Mongodb VM
resource "azurerm_network_security_group" "mongodb_nsg" {
  name                = "terraform-mongodb-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH_From_Nginx"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt SSH från Nginx privata IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Mongodb_From_Nginx"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017" # Standardport för Mongodb
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt Mongodb-trafik från Nginx privata IP
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Test"
    project     = "NewRGTest-Mongodb"
  }
}

# Koppla NSG till Mongodb NIC
resource "azurerm_network_interface_security_group_association" "mongodb_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.mongodb_nic.id
  network_security_group_id = azurerm_network_security_group.mongodb_nsg.id
}

# 16. Virtuell maskin för Mongodb
resource "azurerm_linux_virtual_machine" "mongodb_vm" { # Nytt lokalt Terraform-namn
  name                  = "terraform-vm-mongodb"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1ls"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.mongodb_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMVO35cdysO5/MQALiI4xx2ZUHM33hYOVbEAOmjBWXDIgZUde7LEkLmW4lhbdXtSRxzBxbPrjzdHTUgYzcVDeVi2PPBgHtaTiNJgi6vTPRyOErqyBg8qrncRW2dNipJErUZ5+S9XQzwiOsSgXl4o465n3O+N5YuiFQhSWlSsDcesIdXkxiJFYTDdeW5whZ1SBzNLUKZveBsPRd3qGmYc+qsnGvfP2etbDX/J0TJcMwYeH1Z6O1RahXdoytxvzcRVS59UqB03XkbYF6nzreRzzkyQKkPTi3WG+/dK8lqrECYBDA0fqFXCC8e9e2dSveJKn3tDQC9zAAu+p/7b3a4NWQrrydNoPMPef18N6TNwNn9ftp6KTEvZxPMAlatvHrnE7+jppVJWoLU3f4tU2FgrcY+7zWpD+ueYGD3eelhjhkSvYFcsy4eH3W5GjbMhdk0bUGli9KYDQFMINRsFhfuy6YidVj2ImK/wBshNNiZE7B8wWOxuJEukQng2m/Xm3Wr7X4ub9zhxyL1UrRmCB2Ca0cwafgybnHrYogtudtViozfjvYliga/L13WR1n5rnjVW9zbZw/BlVgUYqTB6d65rkLV4keWkrx8oJqyfX1YnHuTPeDyV40i0PWljg/yN1FqtF17c2NBcd91ol/o7pHvgL1gWdxJFiZRdHpAjPECYWQbw== martin.wallin@lerniastudent.se"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference { 
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts-daily"
    sku       = "server-gen1"
    version   = "latest"
  }

  tags = {
    environment = "Test"
    createdBy   = "Terraform"
    project     = "NewRGTest-Mongodb"
    role        = "mongodb"
  }
}

# --- MinIO VM Resurser ---

# 17. Nätverkskort (NIC) för MinIO VM (ingen publik IP)
resource "azurerm_network_interface" "minio_nic" {
  name                = "terraform-minio-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    # Ingen public_ip_address_id här
  }
  depends_on = [
    azurerm_subnet.vm_subnet
  ]
}

# 18. Nätverkssäkerhetsgrupp (NSG) för MinIO VM
resource "azurerm_network_security_group" "minio_nsg" {
  name                = "terraform-minio-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH_From_Nginx"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt SSH från Nginx privata IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MinIO_From_Nginx"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9001" # Standardport för MinIO console
    source_address_prefix      = azurerm_network_interface.nginx_nic.private_ip_address # Tillåt MinIO-trafik från Nginx privata IP
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Test"
    project     = "NewRGTest-MinIO"
  }
}

# Koppla NSG till MinIO NIC
resource "azurerm_network_interface_security_group_association" "minio_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.minio_nic.id
  network_security_group_id = azurerm_network_security_group.minio_nsg.id
}

# 19. Virtuell maskin för MinIO
resource "azurerm_linux_virtual_machine" "minio_vm" { # Nytt lokalt Terraform-namn
  name                  = "terraform-vm-minio"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_DS1_v2" # Kan vara mindre om det bara är DB
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.minio_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMVO35cdysO5/MQALiI4xx2ZUHM33hYOVbEAOmjBWXDIgZUde7LEkLmW4lhbdXtSRxzBxbPrjzdHTUgYzcVDeVi2PPBgHtaTiNJgi6vTPRyOErqyBg8qrncRW2dNipJErUZ5+S9XQzwiOsSgXl4o465n3O+N5YuiFQhSWlSsDcesIdXkxiJFYTDdeW5whZ1SBzNLUKZveBsPRd3qGmYc+qsnGvfP2etbDX/J0TJcMwYeH1Z6O1RahXdoytxvzcRVS59UqB03XkbYF6nzreRzzkyQKkPTi3WG+/dK8lqrECYBDA0fqFXCC8e9e2dSveJKn3tDQC9zAAu+p/7b3a4NWQrrydNoPMPef18N6TNwNn9ftp6KTEvZxPMAlatvHrnE7+jppVJWoLU3f4tU2FgrcY+7zWpD+ueYGD3eelhjhkSvYFcsy4eH3W5GjbMhdk0bUGli9KYDQFMINRsFhfuy6YidVj2ImK/wBshNNiZE7B8wWOxuJEukQng2m/Xm3Wr7X4ub9zhxyL1UrRmCB2Ca0cwafgybnHrYogtudtViozfjvYliga/L13WR1n5rnjVW9zbZw/BlVgUYqTB6d65rkLV4keWkrx8oJqyfX1YnHuTPeDyV40i0PWljg/yN1FqtF17c2NBcd91ol/o7pHvgL1gWdxJFiZRdHpAjPECYWQbw== martin.wallin@lerniastudent.se"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference { 
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts-daily"
    sku       = "server-gen1"
    version   = "latest"
  }

  tags = {
    environment = "Test"
    createdBy   = "Terraform"
    project     = "NewRGTest-MinIO"
    role        = "minio"
  }
}

# Output för att visa Nginx VM:ens publika IP-adress
output "nginx_vm_public_ip_address" {
  value = azurerm_public_ip.nginx_pub_ip.ip_address # Refererar direkt till Nginx PIP
}

# Output för att visa MariaDB VM:ens privata IP-adress (för referens)
output "mariadb_vm_private_ip_address" {
  value = azurerm_network_interface.mariadb_nic.private_ip_address
}
# Output för att visa Wordpress VM:ens privata IP-adress (för referens)
output "wordpress_vm_private_ip_address" {
  value = azurerm_network_interface.wordpress_nic.private_ip_address
}# Output för att visa Mongodb VM:ens privata IP-adress (för referens)
output "mongodb_vm_private_ip_address" {
  value = azurerm_network_interface.mongodb_nic.private_ip_address
}
# Output för att visa MinIO VM:ens privata IP-adress (för referens)
output "minio_vm_private_ip_address" {
  value = azurerm_network_interface.minio_nic.private_ip_address
}