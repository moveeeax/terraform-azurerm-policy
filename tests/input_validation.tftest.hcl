# Input validation tests.
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

run "rejects_policy_rule_that_is_not_json" {
  command = plan

  variables {
    policy_rule = "this is not json"
  }

  expect_failures = [var.policy_rule]
}

run "rejects_policy_rule_without_then_block" {
  command = plan

  variables {
    policy_rule = jsonencode({
      if = { field = "tags['Environment']", exists = "false" }
    })
  }

  expect_failures = [var.policy_rule]
}

run "rejects_policy_rule_with_empty_effect" {
  command = plan

  variables {
    policy_rule = jsonencode({
      if   = { field = "tags['Environment']", exists = "false" }
      then = { effect = "" }
    })
  }

  expect_failures = [var.policy_rule]
}

run "rejects_unknown_mode" {
  command = plan

  variables {
    mode = "Index"
  }

  expect_failures = [var.mode]
}

run "rejects_a_resource_provider_mode_without_the_data_suffix" {
  command = plan

  variables {
    mode = "Microsoft.KeyVault"
  }

  expect_failures = [var.mode]
}

run "accepts_resource_provider_mode" {
  command = plan

  variables {
    mode = "Microsoft.KeyVault.Data"
  }

  assert {
    condition     = azurerm_policy_definition.this.mode == "Microsoft.KeyVault.Data"
    error_message = "Resource provider modes must be accepted."
  }
}

run "rejects_non_object_parameters" {
  command = plan

  variables {
    parameters = jsonencode(["effect"])
  }

  expect_failures = [var.parameters]
}

run "rejects_assignment_parameters_missing_the_value_wrapper" {
  command = plan

  variables {
    assignment_scope_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg"
    assignment_parameters = jsonencode({ tagName = "Environment" })
  }

  expect_failures = [var.assignment_parameters]
}

run "rejects_a_subscription_id_as_the_assignment_scope" {
  command = plan

  variables {
    assignment_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.assignment_scope_id]
}

run "rejects_unknown_identity_type" {
  command = plan

  variables {
    identity_type = "SystemManaged"
  }

  expect_failures = [var.identity_type]
}

run "rejects_an_over_long_name" {
  command = plan

  variables {
    name = "a-policy-definition-name-that-is-well-over-the-sixty-four-character-limit-azure-enforces"
  }

  expect_failures = [var.name]
}
