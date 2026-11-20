#create a new file output.tf copy from line 2 till 10
  output "rgname" {
  description = "this is the name of the resource group"
  value = azurerm_resource_group.myrg.name
}

output "location" {
  description = "this is the location of the resource group"
  value = azurerm_resource_group.myrg.location
}

##do terraform apply this will show the resource group name and location in terraform console
  #if you want to see the output only give a command terraform output
  ###exercise
  1. inside the output.tf file create a new output block and show the vnetname 
