output "id" {
  description = "ID of the policy definition."
  value       = azurerm_policy_definition.this.id
}

output "name" {
  description = "Name of the policy definition."
  value       = azurerm_policy_definition.this.name
}

output "assignment_id" {
  description = "ID of the resource group policy assignment, if one was created."
  value       = try(azurerm_resource_group_policy_assignment.this[0].id, null)
}
