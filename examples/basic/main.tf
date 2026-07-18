terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_id" {
  description = "ID of the resource group to assign the policy to."
  type        = string
}

module "policy" {
  source = "../.."

  name         = "require-environment-tag"
  display_name = "Require an Environment tag on resources"
  description  = "Denies resource creation unless an Environment tag is present."

  policy_rule = jsonencode({
    if = {
      field  = "tags['Environment']"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })

  assignment_scope_id = var.resource_group_id
}

output "policy_id" {
  value = module.policy.id
}
