##on your desktop in rdp you can create a folder tf-project
##then open visual studio code click on file open folder select desktop and select the folder tf-project
##once selected again click on file click on Auto Save option
##inside vs code on the left side where it is showing tf-project on right side click on the plus icon and give the file name as provider.tf
#inside the provider file  copy from line 7 till 19
//cloud service provider configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm" 
      version = "=5.0.0" #in prod version is always important
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

###then on the top of the menu you will see three dots click on the same terminal open new terminal in vs code you will see a terminal has opened
##now in the terminal give a command terraform init
##you will see it will creata a . terraform folder inside the folder it will download the plugin 
