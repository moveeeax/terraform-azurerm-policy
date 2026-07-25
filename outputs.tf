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

output "assignment_identity_principal_id" {
  description = "Principal ID of the assignment's managed identity, if one was created. Grant this the roles a DeployIfNotExists or Modify policy needs to remediate."
  value       = try(azurerm_resource_group_policy_assignment.this[0].identity[0].principal_id, null)
}

output "effective_effect" {
  description = "Effect the policy will actually apply, with any [parameters('...')] reference resolved through the assignment values and parameter defaults. Empty when it cannot be resolved statically."
  value       = local.effective_effect
}
