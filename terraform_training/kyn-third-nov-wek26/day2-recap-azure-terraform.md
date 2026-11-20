# Day 2 Recap – Terraform on Microsoft Azure

## Learning objectives

Today we extended the Terraform foundation by using input variables, locals, collection types, `for_each`, resource references, Azure networking resources, Network Security Groups (NSGs), and outputs.

## 1. AzureRM provider

We pinned the AzureRM provider version for consistent lab execution.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.0.0"
    }
  }
}
provider "azurerm" {
  features {}
}
```

Authenticate before running Terraform. For a local lab, use `az login` and `az account show`.

## 2. Input variables

Variables make configurations reusable and reduce hard-coded values.

```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-kyn-gopal"
}
variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "business_unit" {
  type    = string
  default = "it"
}
variable "vnet_name" {
  type    = string
  default = "kyn-vnet"
}
variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}
```

Concepts: variable declarations, descriptions, type constraints, default values, strings, and lists.

## 3. Map of objects

A map of objects describes multiple subnet configurations through one structured input.

```hcl
variable "subnets" {
  description = "Configuration for Azure subnets"
  type = map(object({
    name              = string
    address_prefix    = list(string)
    availability_zone = string
  }))
  default = {
    subnet1 = {
      name              = "web-subnet-az1"
      address_prefix    = ["10.0.1.0/24"]
      availability_zone = "1"
    }
    subnet2 = {
      name              = "web-subnet-az2"
      address_prefix    = ["10.0.2.0/24"]
      availability_zone = "2"
    }
  }
}
```

Each map key identifies an object; each object contains related attributes. Add another map entry to scale the configuration without duplicating the resource block.

**Azure design clarification:** Azure subnets are regional network constructs inside a VNet; they are not deployed into Availability Zones. The `availability_zone` field here is metadata for a later zone-aware resource, such as a VM. Use it in a VM's `zone` argument where supported, not on the subnet.

## 4. Local values and naming convention

Locals centralize calculated values and reusable tags.

```hcl
locals {
  resource_name_prefix = "${var.environment}-${var.business_unit}"
  project_tags = {
    environment   = var.environment
    business_unit = var.business_unit
    Project       = "kyn"
  }
}
```

With the defaults, the prefix is `dev-it`.

## 5. Resource Group and Virtual Network

```hcl
resource "azurerm_resource_group" "myrg" {
  name     = "${local.resource_name_prefix}-${var.resource_group_name}"
  location = var.location
  tags     = local.project_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_name_prefix}-${var.vnet_name}"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
  address_space       = var.vnet_address_space
  tags                = local.project_tags
}
```

The default Resource Group name becomes `dev-it-rg-kyn-gopal`; the VNet name becomes `dev-it-kyn-vnet`. References to the Resource Group's name and location also express Terraform dependencies.

## 6. Create multiple subnets with for_each

```hcl
resource "azurerm_subnet" "web_subnet" {
  for_each             = var.subnets
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefix
}
```

- `for_each` iterates over the subnet map.
- `each.key` is the key (for example, `subnet1`).
- `each.value` is the object associated with that key.
- `each.value.name` and `each.value.address_prefix` read object attributes.

One resource block creates two subnet instances.

## 7. Public IP addresses

```hcl
resource "azurerm_public_ip" "web_pip" {
  for_each            = var.subnets
  name                = "pip-${each.key}"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.project_tags
}
```

The map keys create one Public IP for each subnet entry. A Public IP is associated with a NIC IP configuration, not directly with a subnet.

## 8. Network interfaces and resource chaining

```hcl
resource "azurerm_network_interface" "web_nic" {
  for_each            = var.subnets
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_pip[each.key].id
  }
  tags = local.project_tags
}
```

Matching keys connect related instances:
- `azurerm_subnet.web_subnet[each.key].id` selects the matching subnet.
- `azurerm_public_ip.web_pip[each.key].id` selects the matching Public IP.

This is resource chaining: one resource consumes an attribute exported by another resource.

## 9. Network Security Group and subnet association

```hcl
resource "azurerm_network_security_group" "web_nsg" {
  name                = "${local.resource_name_prefix}-nsg"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
  tags                = local.project_tags
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  for_each                  = azurerm_subnet.web_subnet
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}
```

One NSG is associated with both subnet instances. Here `for_each` iterates over the subnet resources created by Terraform.

## 10. NSG rules using a local map

```hcl
locals {
  web_nsg_rule = {
    "110" = "22"
    "120" = "80"
    "140" = "443"
  }
}

resource "azurerm_network_security_rule" "web_nsg_rule" {
  for_each                    = local.web_nsg_rule
  name                        = "Rule_port_${each.value}"
  priority                    = tonumber(each.key)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.myrg.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}
```

The map key supplies the priority and the value supplies the destination port. `tonumber(each.key)` converts the string key to a number.

**Security reminder:** this sample permits SSH (TCP/22) from any source. In a real environment, restrict SSH to a trusted public IP CIDR (for example, a specific `/32`) or an approved management network. Expose HTTP/HTTPS publicly only when that is intended.

## 11. Outputs

```hcl
output "rgname" {
  description = "Resource Group name"
  value       = azurerm_resource_group.myrg.name
}
output "location" {
  description = "Resource Group location"
  value       = azurerm_resource_group.myrg.location
}
output "public_ip_addresses" {
  value = {
    for key, pip in azurerm_public_ip.web_pip : key => pip.ip_address
  }
}
output "nic_ids" {
  value = {
    for key, nic in azurerm_network_interface.web_nic : key => nic.id
  }
}
```

Outputs expose useful deployment values. The map outputs retain the relationship between each key and its resulting address or NIC ID.

## 12. Resource relationship overview

```text
Resource Group
└── Virtual Network (10.0.0.0/16)
    ├── Subnet 1 (10.0.1.0/24) ── NIC 1 ── Public IP 1
    └── Subnet 2 (10.0.2.0/24) ── NIC 2 ── Public IP 2

Resource Group
└── Network Security Group
    ├── Inbound TCP/22
    ├── Inbound TCP/80
    └── Inbound TCP/443

Same NSG is associated with both subnets.
```

Terraform determines creation order from resource references. Explicit `depends_on` is usually unnecessary when a direct reference already expresses the dependency.

## 13. Terraform workflow

Run these commands in the configuration directory:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Review the plan before applying. To remove lab resources after the exercise:

```bash
terraform destroy
```

Confirm that no required data or shared resources depend on the lab before destroying resources.

## 14. Key takeaways

1. Variables make configurations reusable.
2. Lists, maps, and objects model structured cloud configuration.
3. Locals centralize derived names and reusable tags.
4. `for_each` creates multiple instances from a collection.
5. Matching keys connect related resources predictably.
6. Resource references build Terraform's dependency graph.
7. NSGs and subnet associations apply network security consistently.
8. Outputs expose useful deployment information.

## 15. Practice exercises

1. Add a third subnet using a non-overlapping CIDR such as `10.0.3.0/24`.
2. Add an `owner` tag through `local.project_tags`.
3. Add an inbound rule for a custom application port with a unique priority.
4. Restrict SSH to your trusted public IP CIDR.
5. Add an output that returns subnet IDs as a map.
6. Run `terraform plan` and inspect the proposed resource instances.

---

**Training repository:** [kyn-third-nov-wek26](https://github.com/gopal1409/kyn-third-nov-wek26)

**Provider version:** AzureRM `5.0.0`
