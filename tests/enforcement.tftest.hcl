# Tests for the "applies cleanly, enforces nothing" failure modes and for the
# identity requirements of remediating effects.
#
# These require Terraform >= 1.7 (or OpenTofu >= 1.7) for `mock_provider`. That
# is a test-only requirement; the module itself still supports >= 1.5.

mock_provider "azurerm" {
  # OpenTofu makes mocked computed attributes known at plan time, and the
  # provider validates policy_definition_id, so give the definition a real-shaped ID.
  mock_resource "azurerm_policy_definition" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/require-environment-tag"
    }
  }
}

variables {
  name         = "require-environment-tag"
  display_name = "Require an Environment tag on resources"

  policy_rule = <<-JSON
    {
      "if": { "field": "tags['Environment']", "exists": "false" },
      "then": { "effect": "deny" }
    }
  JSON
}

run "definition_only_creates_no_assignment" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group_policy_assignment.this) == 0
    error_message = "No assignment must be created when assignment_scope_id is null."
  }
}

run "assignment_defaults_enforce" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
  }

  assert {
    condition     = azurerm_resource_group_policy_assignment.this[0].enforce
    error_message = "Assignments must enforce by default; DoNotEnforce mode blocks nothing."
  }

  assert {
    condition     = length(azurerm_resource_group_policy_assignment.this[0].identity) == 0
    error_message = "A deny policy must not be given a managed identity it does not need."
  }

  assert {
    condition     = output.effective_effect == "deny"
    error_message = "A literal effect must be reported verbatim."
  }
}

run "deploy_if_not_exists_without_an_identity_is_rejected" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    policy_rule = jsonencode({
      if = { field = "type", equals = "Microsoft.Storage/storageAccounts" }
      then = {
        effect  = "DeployIfNotExists"
        details = { type = "Microsoft.Insights/diagnosticSettings" }
      }
    })
  }

  expect_failures = [azurerm_resource_group_policy_assignment.this]
}

run "an_identity_without_a_location_is_rejected" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    identity_type       = "SystemAssigned"
    policy_rule = jsonencode({
      if = { field = "type", equals = "Microsoft.Storage/storageAccounts" }
      then = {
        effect  = "DeployIfNotExists"
        details = { type = "Microsoft.Insights/diagnosticSettings" }
      }
    })
  }

  expect_failures = [azurerm_resource_group_policy_assignment.this]
}

run "user_assigned_identity_without_ids_is_rejected" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    identity_type       = "UserAssigned"
    location            = "westeurope"
  }

  expect_failures = [azurerm_resource_group_policy_assignment.this]
}

run "deploy_if_not_exists_with_an_identity_and_location_is_accepted" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    identity_type       = "SystemAssigned"
    location            = "westeurope"
    policy_rule = jsonencode({
      if = { field = "type", equals = "Microsoft.Storage/storageAccounts" }
      then = {
        effect  = "DeployIfNotExists"
        details = { type = "Microsoft.Insights/diagnosticSettings" }
      }
    })
  }

  assert {
    condition     = azurerm_resource_group_policy_assignment.this[0].identity[0].type == "SystemAssigned"
    error_message = "The assignment must carry the requested managed identity."
  }

  assert {
    condition     = azurerm_resource_group_policy_assignment.this[0].location == "westeurope"
    error_message = "The assignment must carry the identity's location."
  }
}

run "a_parameter_without_a_default_must_be_supplied_at_assignment_time" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    parameters = jsonencode({
      tagName = { type = "String", metadata = { displayName = "Tag name" } }
    })
    policy_rule = jsonencode({
      if   = { field = "tags[parameters('tagName')]", exists = "false" }
      then = { effect = "deny" }
    })
  }

  expect_failures = [azurerm_resource_group_policy_assignment.this]
}

run "a_parameterised_effect_resolves_through_its_default" {
  command = plan

  variables {
    parameters = jsonencode({
      effect = { type = "String", defaultValue = "Audit", allowedValues = ["Audit", "Deny", "Disabled"] }
    })
    policy_rule = jsonencode({
      if   = { field = "tags['Environment']", exists = "false" }
      then = { effect = "[parameters('effect')]" }
    })
  }

  assert {
    condition     = output.effective_effect == "audit"
    error_message = "A parameterised effect must resolve through the parameter's defaultValue."
  }
}

run "an_assignment_value_overrides_the_parameter_default" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    parameters = jsonencode({
      effect = { type = "String", defaultValue = "Audit", allowedValues = ["Audit", "Deny", "Disabled"] }
    })
    assignment_parameters = jsonencode({ effect = { value = "Deny" } })
    policy_rule = jsonencode({
      if   = { field = "tags['Environment']", exists = "false" }
      then = { effect = "[parameters('effect')]" }
    })
  }

  assert {
    condition     = output.effective_effect == "deny"
    error_message = "An assignment parameter value must win over the definition's defaultValue."
  }
}

run "a_policy_that_resolves_to_disabled_is_reported" {
  command = plan

  variables {
    parameters = jsonencode({
      effect = { type = "String", defaultValue = "Disabled", allowedValues = ["Audit", "Deny", "Disabled"] }
    })
    policy_rule = jsonencode({
      if   = { field = "tags['Environment']", exists = "false" }
      then = { effect = "[parameters('effect')]" }
    })
  }

  expect_failures = [check.policy_effect_is_enforcing]
}

run "an_unknown_effect_is_reported" {
  command = plan

  variables {
    policy_rule = jsonencode({
      if   = { field = "tags['Environment']", exists = "false" }
      then = { effect = "block" }
    })
  }

  expect_failures = [check.policy_effect_is_recognised]
}
