#first generate an graph using terraform graph and paste inside this website https://dreampuf.github.io/GraphvizOnline/
# First Exercise: you will see that there is no vm with nic card
  ##lets create a file vm.tf copy from line 4 till 34
  resource "azurerm_linux_virtual_machine" "web_vm" {
  for_each             = var.subnets
  name                = "${local.resource_name_prefix}-vm-${each.key}"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  size                = "Standard_F2"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.web_nic[each.key].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pem.pub")
    #this path.module terraform argument it will look for the file inside the current directroy where the terraform file is located. In this case, it will look for the file inside the ssh_keys folder.
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
  custom_data = base64encode(file("${path.module}/app.sh")) #this path.module terraform argument it will look for the file inside the current directroy where the terraform file is located. In this case, it will look for the file inside the app.sh folder.
  tags                = local.project_tags
}

#exrcises
  1. do terraform apply this will create your virtual machine
  2. do terraform graph and go to this website https://dreampuf.github.io/GraphvizOnline/ and paste it you will see the vm connection with nic card
  3. once terraform apply complete go to azure portal inside your resource group you will see a vm open the vm and copy the public and compare the publci ip with the terraform console public ip it should match
  4. now copy the public ip and paste it in the browser remove the https as our website run on http
  5. now in vs code console lets login to the instance
  cd .\ssh-keys\     
  #change the public ip to your public ip
  ssh -i .\terraform-azure.pem azureuser@20.25.84.170  
  ##lets see the same website using curl request 
  curl localhost
  exit
  cd ..  
