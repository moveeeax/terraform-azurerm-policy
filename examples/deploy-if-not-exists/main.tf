/*
 * A DeployIfNotExists policy. Unlike Deny, this effect is remediated by the
 * assignment's own managed identity, so the assignment needs both an identity
 * and a location. Omitting either leaves a policy that applies cleanly and
 * remediates nothing, so the module refuses to plan it.
 *
 * The identity still needs Azure RBAC roles to do its work: grant
 * `assignment_identity_principal_id` the roles listed in the rule's
 * `roleDefinitionIds` before expecting remediation to succeed.
 */

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

variable "subscription_id" {
  description = "Subscription to create the policy definition in. Required by azurerm 4.x and accepted by 3.x."
  type        = string
}

variable "resource_group_id" {
  description = "ID of the resource group to assign the policy to."
  type        = string
}

variable "location" {
  description = "Region for the assignment's managed identity."
  type        = string
  default     = "westeurope"
}

variable "log_analytics_workspace_id" {
  description = "Workspace that storage account diagnostics should be sent to."
  type        = string
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

module "policy" {
  source = "../.."

  name         = "deploy-storage-diagnostics"
  display_name = "Deploy diagnostic settings for storage accounts"
  description  = "Sends storage account diagnostics to a central Log Analytics workspace."

  # DeployIfNotExists only evaluates resources that carry tags and a location,
  # so Indexed rather than All is the correct mode here.
  mode = "Indexed"

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Storage/storageAccounts"
    }
    then = {
      effect = "DeployIfNotExists"
      details = {
        type = "Microsoft.Insights/diagnosticSettings"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
        ]
        existenceCondition = {
          field  = "Microsoft.Insights/diagnosticSettings/workspaceId"
          equals = "[parameters('workspaceId')]"
        }
        deployment = {
          properties = {
            mode       = "incremental"
            parameters = {}
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              resources      = []
            }
          }
        }
      }
    }
  })

  # workspaceId has no defaultValue, so the module requires an assignment value
  # for it: without one Azure would reject the assignment.
  parameters = jsonencode({
    workspaceId = {
      type     = "String"
      metadata = { displayName = "Log Analytics workspace ID" }
    }
  })

  assignment_scope_id   = var.resource_group_id
  assignment_parameters = jsonencode({ workspaceId = { value = var.log_analytics_workspace_id } })

  identity_type = "SystemAssigned"
  location      = var.location
}

output "policy_id" {
  value = module.policy.id
}

output "assignment_identity_principal_id" {
  description = "Grant this principal the roles in roleDefinitionIds so remediation can run."
  value       = module.policy.assignment_identity_principal_id
}
