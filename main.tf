resource "azurerm_policy_definition" "this" {
  name         = var.name
  display_name = var.display_name
  policy_type  = var.policy_type
  mode         = var.mode
  description  = var.description

  policy_rule = var.policy_rule
  parameters  = var.parameters
}

resource "azurerm_resource_group_policy_assignment" "this" {
  count = var.assignment_scope_id == null ? 0 : 1

  name                 = var.name
  display_name         = var.display_name
  resource_group_id    = var.assignment_scope_id
  policy_definition_id = azurerm_policy_definition.this.id
  parameters           = var.assignment_parameters
}
